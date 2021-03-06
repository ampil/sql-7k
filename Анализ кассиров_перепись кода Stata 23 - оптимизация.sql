

/*	Запуск на SQL-Store, FrontStore
	Вся процедура работает 4,5 минуты
*/
--Общие условия:
--Начало смены с 8 утра
--Конец смены до 22 вечера (включительно)
--Всех кассиров 7К из штатки выводим на кассы
--Заполняем нехватки по часам кассирами аутсорса: 
	--а) сначала по 12 часовым дневным сменам (чотбы ускорить расчет и закрыть как можно больше окон), при этом оставив нехватку в 2 кассира для более мелкой оптимизации (по 8-12 часов)
	--б) потом ночные смены по 8-9-10-11-12 часов
	--в) отдельно расчет для понедельникаи воскресенья (когда нет прошлой даты и следующей)
	--г) потом рассматриваем оптимальные дневные окна по 8-9-10-11-12 часов и закрываем сначала самое больше (и первое по порядку) окно. Оптимизация происходит до тех пор, пока не останется максимум 2 кассиро-нехватки за весь день (сумма всех нехваток >=2)
--Нормой считается суммарная нехватка кассиров на 2 часа за весь день (включая дневные и ночные смены)
--Расчет фактического кол-ва кассиров в смену: Общее кол-во людей по штату (с учетом неявок) делится пололам. Если в результате появилось нечетное число, то считаем что 1 человек работает в пятидневку по 12 часов
--Если нужно ограничить кол-во часов (один из вариантов - убрать уже насчитанных кассиров), нужно исходить из таблицы #KassirShort, постепенно убирая кассиров п очасам, начиная с последнего прохода (@prohod)


Print convert(varchar(10),getdate(),102) + ' ' + convert(varchar(8),getdate(),108) + ' Запуск расчета'

--if @ToDay is null Set @ToDay = convert(date,getdate())
--if @K is null Set @K = 0.7

DECLARE @AfterOpt int = 4 --максимальное кол-во нужды в кассирах аутсорса, которое оставляем в каждый час для дальнейшенй оптимизации по более мелким сменам. Чем больше оставим - тем более мелкие могут быть окна, но дольше выполнение.
declare @SeniorKassir_RKO_day int = 2 --задаем границу, сколько человеко-часов нехватки можно оставить в дневное время. Используется в пункте III.c. @SeniorKassir_RKO_day должен быть не больше @AfterOpt.
declare @SeniorKassir_RKO_night int = 0 --сколько нехватки оставляем в ночные смены. 0 - на ночь все "дыры" (нехватки человеко-часов) будут закрыты. Используется в пункте III.b


/* I. Предварительные шаги */
/*****************************************BLOCK BEGIN**********************************************************/
--1. Данные о рекомендациях в час (запись в таблицу pf 01:05)
IF OBJECT_ID('tempdb..#Recomendations') IS NOT NULL BEGIN DROP TABLE #Recomendations END	
Create TABLE #Recomendations
([Код магазина] int, Магазин varchar(255), [Дата базы] date, [Дата прогноза] date, [День недели] varchar(255), time int, [Диапазон времени] varchar(255)
, [Кассиров по факту на прошлой неделе] int, [Работало касс на прошлой неделе] int, [Чеков на прошлой неделе] int, [К-т прогноза] decimal(18,3), [Прогноз кассиров] int)

declare @ToDay date = '2015-07-07' -- convert(date,getdate()) --вне зависимости от дня (пн, вт, ср, .. вс.), расчет будет сделан на всю неделю
declare @K decimal(18,3) = 0.7
insert into #Recomendations EXEC [FrontStore].[dbo].[KassirForecast] @ToDay, @K


--2. Фактическое кол-во кассиров на сегодняшний день (параметра выбора даты нет)
IF OBJECT_ID('tempdb..#vacancy_pre') IS NOT NULL BEGIN DROP TABLE #vacancy_pre END 
Create TABLE #vacancy_pre
(date date, Name_appoint varchar(max), [Всего ставок на текущую дату] decimal(18,3), [кол-во] int, Name_Regim varchar(max), struct_name varchar(max), ShopId int)

insert into #vacancy_pre EXEC bosshr.[AIT].[dbo].[avv_out_cass_vacancy] --параметра выбора даты нет

IF OBJECT_ID('tempdb..#vacancy') IS NOT NULL BEGIN DROP TABLE #vacancy END 
select t1.ShopId, SUM(FactKassir) as FactKassir, convert(int,sum(MaxKassir)) as MaxKassir
into #vacancy
from
  (select ShopId, Name_appoint, [Всего ставок на текущую дату] as MaxKassir, SUM([кол-во]) as FactKassir
  from #vacancy_pre
  group by ShopId, Name_appoint, [Всего ставок на текущую дату]) t1
group by t1.ShopId


--3. Неявки на период прогноза
IF OBJECT_ID('tempdb..#Calendar') IS NOT NULL BEGIN DROP TABLE #Calendar END 
Create TABLE #Calendar
([выходы кассиров без учета кассиров с гибким графиком и кассиров без графика] int
, d date, [name] varchar(max), struct_name varchar(max), ShopId int, count int)

declare @Monday date = dateadd(day, -1, (select top 1 [Дата прогноза] from #Recomendations order by [Дата прогноза] asc))
--отнимаем один день, чтобы взять данные по неявкам за всю неделю (ну так устроен алгоритм процедуры)

insert into #Calendar
EXEC bosshr.[AIT].[dbo].[avv_out_cass_calendar] @Monday 


--4. Создание рабочей таблицы
IF OBJECT_ID('tempdb..#RawData') IS NOT NULL BEGIN DROP TABLE #RawData END 

select distinct t1.[Код магазина], t1.[Дата прогноза], t1.[День недели], t1.time, t1.[Диапазон времени], t1.[Прогноз кассиров]
, t1.[Прогноз кассиров] as [Прогноз кассиров Исходный], V.FactKassir, V.MaxKassir
, CEILING((SELECT cast((V.factkassir-isnull(C.count,0)) as float)) / 2) as [Кассиров из ШР] --кол-во людей в смене с учетом неявок. Общее кол-во делится пололам, если нечетное, то считаем что 1 человек работает в пятидневку
, isnull(C.count,0) as [Неявки]
into #RawData
from #Recomendations t1
join #vacancy V on V.ShopId=t1.[Код магазина] --join: автоматом убираем закрытие магазины, где уже нет штата
left join #Calendar C on C.ShopId=t1.[Код магазина] and C.d=t1.[Дата прогноза]


DECLARE @AfterOpt int = 4 --максимальное кол-во нужды в кассирах аутсорса, которое оставляем в каждый час для дальнейшенй оптимизации по более мелким сменам. Чем больше оставим - тем более мелкие могут быть окна, но дольше выполнение.
declare @SeniorKassir_RKO_day int = 2 --задаем границу, сколько человеко-часов нехватки можно оставить в дневное время. Используется в пункте III.c. @SeniorKassir_RKO_day должен быть не больше @AfterOpt.
declare @SeniorKassir_RKO_night int = 0 --сколько нехватки оставляем в ночные смены. 0 - на ночь все "дыры" (нехватки человеко-часов) будут закрыты. Используется в пункте III.b



--5. Создаем таблицу с результатами по сменам кассиров 7К
IF OBJECT_ID('tempdb..#KassirShort') IS NOT NULL BEGIN DROP TABLE #KassirShort END	
Create TABLE #KassirShort ([shopid] int, [date] date, [Type] varchar(20), RecNumber int, [TimeStart] int, [TimeEnd] int, [WorkingHour] int, Проход int)

--6. Создаем таблицу с результатами по сменам кассиров аутсорс (необязательно, но легче делать debug алгоритма)
IF OBJECT_ID('tempdb..#KassirShort_OutS') IS NOT NULL BEGIN DROP TABLE #KassirShort_OutS END	
Create TABLE #KassirShort_OutS ([shopid] int, [date] date, [Type] varchar(20), RecNumber int, [TimeStart] int, [TimeEnd] int, [WorkingHour] int, Проход int)
/*****************************************BLOCK END**********************************************************/



/* II. Распределение кассиров 7К [00:15 вся сеть] */
/*****************************************BLOCK BEGIN**********************************************************/
Print convert(varchar(10),getdate(),102) + ' ' + convert(varchar(8),getdate(),108) + ' Расчет по кассирам 7К'
--Обнуление данных, в случае их изменения (используется для отладки)
update #RawData
set [Прогноз кассиров]=[Прогноз кассиров Исходный]

truncate table #KassirShort

--Задание параметров: кол-во проходов алгоритма по таблице (шагов оптимизации), расчет делается по каждому магазину
DECLARE @prohod INT, @ShopId int, @MaxProhod int
DECLARE @MaxShopId int = (select max([Код магазина]) from #RawData) --Максимльынй код магазина
SET @ShopId = 1

--Начало цикла
WHILE @ShopId <= @MaxShopId
BEGIN

	SET @MaxProhod = (select top 1 [Кассиров из ШР] from #RawData where [Код магазина]=@ShopId) --устанавливаем для каждого магазина кол-во кассиров по ШР = кол-во проходов. Т.е. каждый кассир 7К так или иначе назначается на время
	--PRINT ''
	--PRINT 'BEGIN ' + convert(varchar(3),@shopid)
	SET @prohod = 1 --для каждого магазина заново ставим счетчик проходов алгоритма

	WHILE @prohod <= @MaxProhod
	BEGIN
		--Шаг 1. Суммирование нагрузки кассиров в каждом 12ч окне
		IF OBJECT_ID('tempdb..#tSum_7K') IS NOT NULL BEGIN DROP TABLE #tSum_7K END	
		
		SELECT [Код магазина],[Дата прогноза]
		  ,sum((case when time >=8 and time<=19 then [Прогноз кассиров] else 0 end)) as FT_8 --начало в 08:00, конец в 20:00
		  ,sum((case when time >=9 and time<=20 then [Прогноз кассиров] else 0 end)) as FT_9 --начало в 09:00, конец в 21:00
		  ,sum((case when time >=10 and time<=21 then [Прогноз кассиров] else 0 end)) as FT_10 --начало в 10:00, конец в 22:00
		  --,sum((case when time >=11 and time<=22 then [Прогноз кассиров] else 0 end)) as FT_11 --начало в 11:00, конец в 23:00
		into #tSum_7K
		FROM #RawData
		where [Код магазина]=@ShopId
		group by [Код магазина],[Дата прогноза]

		--Шаг 2. Выбор самого нуждающегося времени
			--сравениваем окна и выбираем самое нагрузочное
			--если суммы одинаковые, ставим кассира там, где смена начианется раньше (как бы учитывая пики нагрузки и очереди до их начала)
		IF OBJECT_ID('tempdb..#tShift_7K') IS NOT NULL BEGIN DROP TABLE #tShift_7K END	
		select distinct [Код магазина],[Дата прогноза]
		, (case 
			when FT_8>=FT_9 and FT_8>=FT_10 then 8 --and FT_8>=FT_11
			when FT_9>=FT_10 and FT_9>FT_8 then 9 --and FT_9>=FT_11
			when FT_10>FT_8 and FT_10>FT_9 then 10 --FT_10>=FT_11 and
			--when FT_11>FT_10 and FT_11>FT_9 and FT_11>FT_8 then 11
		end) as [Начало смены]
		into #tShift_7K
		from #tSum_7K
		
		--Шаг 3. Назначение кассира в выбранное время: уменьшаем нашу рекомендацию на один в обозначенный промежуток времени
		UPDATE RD
		SET RD.[Прогноз кассиров] = RD.[Прогноз кассиров] - 1
		FROM #RawData RD
		join #tShift_7K tS on tS.[Код магазина]=RD.[Код магазина] and tS.[Дата прогноза]=RD.[Дата прогноза]
		where RD.time>=tS.[Начало смены] and RD.time<=(tS.[Начало смены]+11)

		--select RD.[Код магазина], RD.[Дата базы], RD.[День недели], RD.time, RD.[Диапазон времени]
		--, RD.[Кассиров из ШР]
		--, RD.[Прогноз кассиров]
		--, tS.[Начало смены]
		--, (case when RD.time>=tS.[Начало смены] and RD.time<=(tS.[Начало смены]+12) then 1 end) as typ
		--FROM #RawData RD
		--join #tShift_7K tS on tS.[Код магазина]=RD.[Код магазина] and tS.[Дата базы]=RD.[Дата базы]
		--order by RD.[Код магазина] , RD.[Дата базы], RD.time

		--Шаг 4. Запись полученной смены (начало, конец, длительность, тип кассира) в таблицу с номером прохода (для отладки)
		insert into #KassirShort
		select distinct [Код магазина], [Дата прогноза], '7К' AS [Type], 1 as RecNumber, [Начало смены] as [TimeStart], [Начало смены]+12 as [TimeEnd], 12 as [WorkingHour], @prohod as [Проход]
		from #tShift_7K
		
		SET @prohod = @prohod + 1 --идем в следующий проход до @MaxProhod
	END
	--PRINT 'DONE ' + convert(varchar(3),@shopid)

	set @shopid = @shopid + 1 --идем в следующий магазин до @MaxShopId
END
--PRINT 'Done FOR LOOP'
--GO
/*****************************************BLOCK END**********************************************************/



/* III. Распределение кассиров Аутсорс */
/*****************************************BLOCK BEGIN**********************************************************/
--III.a Дневные окна по 12 часов [00:34]
Print convert(varchar(10),getdate(),102) + ' ' + convert(varchar(8),getdate(),108) + ' Расчет по кассирам аутсорса - дневные окна по 12 часов'
--truncate table #KassirShort_OutS

--Задание параметров
DECLARE @prohodO1 INT, @ShopIdO1 int, @MaxProhodO1 int, @DateO1 date
DECLARE @MaxShopIdO1 int = (select max([Код магазина]) from #RawData) --Максимальынй код магазина
SET @ShopIdO1 = 1
declare @DateMaxO1 date = (select max([Дата прогноза]) from #RawData)

--Начало цикла
WHILE @ShopIdO1 <= @MaxShopIdO1
BEGIN
SET @DateO1 = (select min([Дата прогноза]) from #RawData) --для каждого магазина заново ставим счетчик даты
	
	WHILE @DateO1<=@DateMaxO1
	BEGIN
	--для каждого магазина и каждой даты находим максимальную нужду кассиров в дневное время, но оставляем резевр в двух человек для будущей оптимизации по более мелким часам
	SET @MaxProhodO1 = (select max([Прогноз кассиров]) - @AfterOpt from #RawData where [Код магазина]=@ShopIdO1 and [Дата прогноза]=@DateO1 and time between 8 and 22)
	--PRINT 'BEGIN ' + convert(varchar(3),@shopidO1)
	
	IF isnull(@MaxProhodO1,0) > 0 --условие, что есть кассиро-часы для оптимизации
	BEGIN
	SET @prohodO1 = 1 --для каждого магазина заново ставим счетчик

		WHILE @prohodO1 <= @MaxProhodO1
		BEGIN
				--Шаг 1. Суммирование нужды
				IF OBJECT_ID('tempdb..#tSum_O1') IS NOT NULL BEGIN DROP TABLE #tSum_O1 END	
				
				SELECT [Код магазина],[Дата прогноза]
				  ,sum((case when time >=8  and time<=19 then [Прогноз кассиров] else 0 end)) as FT_8 --начало в 08:00, конец в 20:00
				  ,sum((case when time >=9  and time<=20 then [Прогноз кассиров] else 0 end)) as FT_9 --начало в 09:00, конец в 21:00
				  ,sum((case when time >=10 and time<=21 then [Прогноз кассиров] else 0 end)) as FT_10 --начало в 10:00, конец в 22:00
				  --,sum((case when time >=11 and time<=22 then [Прогноз кассиров] else 0 end)) as FT_11 --начало в 11:00, конец в 23:00
				  --сколько людей нужна максимум в каждый час. Нехватка в 2 человека в течении всего дня - норма
				  ,max((case when time >=8  and time<=19 then [Прогноз кассиров] else 0 end)) as mHour_8 
				  ,max((case when time >=9  and time<=20 then [Прогноз кассиров] else 0 end)) as mHour_9 
				  ,max((case when time >=10 and time<=21 then [Прогноз кассиров] else 0 end)) as mHour_10 
				into #tSum_O1
				FROM #RawData
				where [Код магазина]=@ShopIdO1
				and [Прогноз кассиров]>0
				group by [Код магазина],[Дата прогноза]


				--Шаг 2. Выбор самого нуждающегося времени
					--если суммы одинаковые, ставим кассира там, где смена начианется раньше (как бы учитывая пики до их начала)
				IF OBJECT_ID('tempdb..#tShift_O1') IS NOT NULL BEGIN DROP TABLE #tShift_O1 END	
				select distinct [Код магазина],[Дата прогноза]
				, (case 
						when FT_8>=FT_9  and FT_8>=FT_10 and mHour_8  >= @AfterOpt then 8 --and FT_8>=FT_11
						when FT_9>=FT_10 and FT_9>FT_8   and mHour_9  >= @AfterOpt then 9 --and FT_9>=FT_11
						when FT_10>FT_8  and FT_10>FT_9  and mHour_10 >= @AfterOpt then 10 --FT_10>=FT_11 and
						--when FT_11>FT_10 and FT_11>FT_9 and FT_11>FT_8 then 11
						--Нехватка в 2 человека в течении всего дня - норма
				end) as [Начало смены]
				into #tShift_O1
				from #tSum_O1
				
				--Шаг 3. Назначение кассира в обозначенное время
				UPDATE RD
				SET RD.[Прогноз кассиров] = RD.[Прогноз кассиров] - 1
				FROM #RawData RD
				join #tShift_O1 tS on tS.[Код магазина]=RD.[Код магазина] and tS.[Дата прогноза]=RD.[Дата прогноза]
				where RD.time>=tS.[Начало смены] and RD.time<=(tS.[Начало смены]+11)
				and ts.[Начало смены] is not null

				--select RD.[Код магазина], RD.[Дата прогноза], RD.[День недели], RD.time, RD.[Диапазон времени]
				--, RD.[Кассиров из ШР]
				--, RD.[Прогноз кассиров]
				--, tS.[Начало смены]
				--, (case when RD.time>=tS.[Начало смены] and RD.time<=(tS.[Начало смены]+11) then 0 end) as typ
				--FROM #RawData RD
				--join #tShift_O1 tS on tS.[Код магазина]=RD.[Код магазина] and tS.[Дата прогноза]=RD.[Дата прогноза]
				--where RD.time>=tS.[Начало смены] and RD.time<=(tS.[Начало смены]+12)
				--order by RD.[Код магазина] , RD.[Дата прогноза], RD.time

				--Шаг 4. Запись полученной смены (начало, конец, длительность, тип кассира) в таблицу с номером прохода
				insert into #KassirShort_OutS
				select distinct [Код магазина], [Дата прогноза], 'Outsource' AS [Type], 1 as RecNumber, [Начало смены] as [TimeStart], [Начало смены]+12 as [TimeEnd], 12 as [WorkingHour], @prohodO1 as [Проход]
				from #tShift_O1
				where [Начало смены] is not null
				
			SET @prohodO1 = @prohodO1 + 1 --идем в следующий проход до @MaxProhod
			END
			--PRINT 'DONE ' + convert(varchar(3),@prohodO1)
			
		END
		--PRINT 'DONE ' + convert(varchar(10),@DateO1)
	
	SET @DateO1 = dateadd(day,1,@DateO1) --Идем в следующий денб
	END
	--PRINT 'DONE SHOP'  + convert(varchar(3),@shopidO1)

SET @ShopIdO1 = @ShopIdO1 + 1 --идем в следующий магазин до @MaxShopId
END
--GO
/*****************************************BLOCK END**********************************************************/



/*****************************************BLOCK BEGIN**********************************************************/
--III.b Ночные окна по 8, 9, 10, 11, 12 часов [00:34]
--Делаем перед дневными окнами, чтобы сначала оптимизировать ночь, которая заканчивается в 8-10 утра. А потом - дневные смены, которые начинаются в 8 утра
--Окна Начало-конец: 20-8, 21-8, 21-9, 22-8, 22-9, 22-10
Print convert(varchar(10),getdate(),102) + ' ' + convert(varchar(8),getdate(),108) + ' Расчет по кассирам аутсорса - ночные смены'

--Задание параметров
DECLARE @prohodO2 INT, @ShopIdO2 int, @MaxProhodO2 int, @DateO2 date
DECLARE @MaxShopIdO2 int = (select max([Код магазина]) from #RawData) --Максимльынй код магазина
SET @ShopIdO2 = 1
declare @DateMaxO2 date = (select max([Дата прогноза]) from #RawData)

--Начало цикла
WHILE @ShopIdO2 <= @MaxShopIdO2
BEGIN
SET @DateO2 = (select min([Дата прогноза]) from #RawData) --для каждого магазина заново ставим счетчик даты
	
	WHILE @DateO2<=@DateMaxO2
	BEGIN
	--для каждого магазина и каждой даты находим максимальную нужду кассиров в ночное-утреннее время
	SET @MaxProhodO2 = (select max([Прогноз кассиров]) from #RawData where [Код магазина]=@ShopIdO2 
						and ( ([Дата прогноза]=@DateO2 and time between 20 and 23) OR ([Дата прогноза]=dateadd(day,1,@DateO2) and time between 0 and 9) ) )
	--PRINT 'BEGIN ' + convert(varchar(3),@shopidO2)
	
	--If @MaxProhodO2 >=4 select @ShopIdO2
	
	IF isnull(@MaxProhodO2,0)>0 --условие, что есть кассиро-часы для оптимизации
	BEGIN
	SET @prohodO2 = 1 --для каждого магазина заново ставим счетчик

		WHILE @prohodO2 <= @MaxProhodO2
		BEGIN
			IF (@DateO2 <> (select min([Дата прогноза]) from #RawData) or @DateO2 <> (select max([Дата прогноза]) from #RawData)) 
			BEGIN
				--Шаг 1. Суммирование нужды
				IF OBJECT_ID('tempdb..#tSum_O2') IS NOT NULL BEGIN DROP TABLE #tSum_O2 END	
		
				--declare @DateO2 date='2015-07-17' 
				
				select distinct isnull(t1.[Код магазина],t2.[Код магазина]) as [Код магазина], isnull(t1.[Дата прогноза], t2.[Дата прогноза]) as [Дата прогноза]
				, isnull(FT_20_8_eve,0) + isnull(FT_20_8_morn,0) as FT_20_8, isnull(FT_21_8_eve,0) + isnull(FT_21_8_morn,0) as FT_21_8, isnull(FT_21_9_eve,0) + isnull(FT_21_9_morn,0) as FT_21_9
				, isnull(FT_22_8_eve,0) + isnull(FT_22_8_morn,0) as FT_22_8, isnull(FT_22_9_eve,0) + isnull(FT_22_9_morn,0) as FT_22_9, isnull(FT_22_10_eve,0) + isnull(FT_22_10_morn,0) as FT_22_10
				into #tSum_O2
				from 
					(SELECT [Код магазина],[Дата прогноза]
					  ,sum(case when time >=20 and time<=23 then [Прогноз кассиров] else 0 end) as FT_20_8_eve --начало в 20:00, конец в 8:00 
					  ,sum(case when time >=21 and time<=23 then [Прогноз кассиров] else 0 end) as FT_21_8_eve --начало в 21:00, конец в 8:00
					  ,sum(case when time >=21 and time<=23 then [Прогноз кассиров] else 0 end) as FT_21_9_eve --начало в 21:00, конец в 9:00
					  ,sum(case when time >=22 and time<=23 then [Прогноз кассиров] else 0 end) as FT_22_8_eve --начало в 22:00, конец в 8:00
					  ,sum(case when time >=22 and time<=23 then [Прогноз кассиров] else 0 end) as FT_22_9_eve --начало в 22:00, конец в 9:00
					  ,sum(case when time >=22 and time<=23 then [Прогноз кассиров] else 0 end) as FT_22_10_eve --начало в 22:00, конец в 10:00
					  --сколько людей нужна максимум в каждый час. Нехватка в 2 человека в течении всего дня - норма
					FROM #RawData
					where [Прогноз кассиров]>0
						and [Дата прогноза]= @DateO2
					group by [Код магазина], [Дата прогноза]) t1
				full outer join 
					(SELECT [Код магазина],[Дата прогноза]
					,sum(case when time >=0 and time<=7 then [Прогноз кассиров] else 0 end) as FT_20_8_morn
					,sum(case when time >=0 and time<=7 then [Прогноз кассиров] else 0 end) as FT_21_8_morn
					,sum(case when time >=0 and time<=8 then [Прогноз кассиров] else 0 end) as FT_21_9_morn
					,sum(case when time >=0 and time<=7 then [Прогноз кассиров] else 0 end) as FT_22_8_morn
					,sum(case when time >=0 and time<=8 then [Прогноз кассиров] else 0 end) as FT_22_9_morn
					,sum(case when time >=0 and time<=9 then [Прогноз кассиров] else 0 end) as FT_22_10_morn
					FROM #RawData
					where [Прогноз кассиров]>0
						and [Дата прогноза]=dateadd(day,1,@DateO2) 
					group by [Код магазина], [Дата прогноза]) t2
				on t2.[Код магазина]=t1.[Код магазина] and t1.[Дата прогноза]=dateadd(day,-1,t2.[Дата прогноза])
				where isnull(t1.[Дата прогноза], t2.[Дата прогноза])=@DateO2
								
				
				--Шаг 2. Выбор самого нуждающегося времени
					--если суммы одинаковые, ставим каиира там, где смена начианется раньше (как бы учитывая пики до их начала)
				IF OBJECT_ID('tempdb..#tShift_O2') IS NOT NULL BEGIN DROP TABLE #tShift_O2 END	
				select distinct [Код магазина],[Дата прогноза]
				--Нехватка в 2 человека в течении всего дня - норма
				, (case 
						
							/*	
					when FT_22_8 >= @SeniorKassir_RKO_night 
							and FT_22_8>=FT_21_8 and FT_22_8>=FT_20_8  
								then 22 
								
					when FT_22_9 >= @SeniorKassir_RKO_night 
							and FT_22_9>=FT_21_9 
								then 22 
								
					when FT_21_8 >= @SeniorKassir_RKO_night 
							and FT_21_8>=FT_21_9
								then 21
					
					when FT_20_8 >= @SeniorKassir_RKO_night 
							and FT_20_8>=FT_21_9
								then 20
					k
					
										
							FT_21_9 and FT_20_8>=FT_22_8 and FT_20_8>=FT_22_9 and FT_20_8>=FT_22_10
						*/
						
						when FT_20_8 >= @SeniorKassir_RKO_night 
							and FT_20_8>=FT_21_8 and FT_20_8>=FT_21_9 and FT_20_8>=FT_22_8 and FT_20_8>=FT_22_9 and FT_20_8>=FT_22_10
								then 20 
								
						when FT_21_8 >= @SeniorKassir_RKO_night 
							and FT_21_8>=FT_21_9 and FT_21_8>=FT_22_8 and FT_21_8>=FT_22_9 and FT_21_8>=FT_22_10
								then 21
						when FT_21_9 >= @SeniorKassir_RKO_night 
							and FT_21_9>=FT_22_8 and FT_21_9>=FT_22_9 and FT_21_9>=FT_22_10
								then 21
						when FT_22_8 >= @SeniorKassir_RKO_night 
							and FT_22_8>=FT_22_9 and FT_22_8>=FT_22_10
								then 22
						when FT_22_9 >= @SeniorKassir_RKO_night 
							and FT_22_9>=FT_22_10
								then 22
						when FT_22_10 >= @SeniorKassir_RKO_night
								then 22
				end) as [Начало смены]
				, (case 
						when FT_20_8 >= @SeniorKassir_RKO_night 
							 and FT_20_8>=FT_21_8 and FT_20_8>=FT_21_9 and FT_20_8>=FT_22_8 and FT_20_8>=FT_22_9 and FT_20_8>=FT_22_10
								then 8
						when FT_21_8 >= @SeniorKassir_RKO_night 
							 and FT_21_8>=FT_21_9 and FT_21_8>=FT_22_8 and FT_21_8>=FT_22_9 and FT_21_8>=FT_22_10
								then 8
						when FT_21_9 >= @SeniorKassir_RKO_night 
							 and FT_21_9>=FT_22_8 and FT_21_9>=FT_22_9 and FT_21_9>=FT_22_10
								then 9
						when FT_22_8 >= @SeniorKassir_RKO_night 
							 and FT_22_8>=FT_22_9 and FT_22_8>=FT_22_10
								then 8
						when FT_22_9 >= @SeniorKassir_RKO_night 
							 and FT_22_9>=FT_22_10
								then 9
						when FT_22_10 >= @SeniorKassir_RKO_night
								then 10
				end) as [Конец смены]
				into #tShift_O2
				from #tSum_O2
				where (FT_20_8 + FT_21_8 + FT_21_9 + FT_22_8 + FT_22_9 + FT_22_10)>0
				
				--select * from #tShift_O2
				
				--Шаг 3. Назначение кассира в обозначенное время
					--Ночью
				UPDATE RD
				SET RD.[Прогноз кассиров] = RD.[Прогноз кассиров] - 1
				FROM #RawData RD
				join #tShift_O2 tS on tS.[Код магазина]=RD.[Код магазина] and tS.[Дата прогноза]=RD.[Дата прогноза]
				where (RD.time>=tS.[Начало смены] and RD.[Дата прогноза]=tS.[Дата прогноза])
				and ts.[Начало смены] is not null and ts.[Конец смены] is not null 
				--	--Утром следующего дня
				UPDATE RD
				SET RD.[Прогноз кассиров] = RD.[Прогноз кассиров] - 1
				FROM #RawData RD
				join #tShift_O2 tS on tS.[Код магазина]=RD.[Код магазина] and dateadd(day,1,tS.[Дата прогноза])=RD.[Дата прогноза]
				where RD.time <= (tS.[Конец смены]-1)
				and ts.[Начало смены] is not null and ts.[Конец смены] is not null 

				--Шаг 4. Запись полученной смены (начало, конец, длительность, тип кассира) в таблицу 
				insert into #KassirShort_OutS
				select distinct  [Код магазина], [Дата прогноза], 'Outsource' AS [Type], 1 as RecNumber, [Начало смены] as [TimeStart], [Конец смены] as [TimeEnd]
				, 24-[Начало смены]+[Конец смены] as [WorkingHour], @prohodO2 as [Проход]
				from #tShift_O2
				where [Начало смены] is not null and [Конец смены] is not null 
			END
			
			SET @prohodO2 = @prohodO2 + 1 --идем в следующий проход до @MaxProhod
			END
			--PRINT 'DONE ' + convert(varchar(3),@prohodO2)
			
		END
		--PRINT 'DONE ' + convert(varchar(10),@DateO2)
	
	SET @DateO2 = dateadd(day,1,@DateO2) --Идем в следующий денб
	END
	--PRINT 'DONE SHOP'  + convert(varchar(3),@shopidO2)

SET @ShopIdO2 = @ShopIdO2 + 1 --идем в следующий магазин до @MaxShopId
END
--GO
/*****************************************BLOCK END**********************************************************/



DECLARE @AfterOpt int = 4 --максимальное кол-во нужды в кассирах аутсорса, которое оставляем в каждый час для дальнейшенй оптимизации по более мелким сменам. Чем больше оставим - тем более мелкие могут быть окна, но дольше выполнение.
declare @SeniorKassir_RKO_day int = 2 --задаем границу, сколько человеко-часов нехватки можно оставить в дневное время. Используется в пункте III.c. @SeniorKassir_RKO_day должен быть не больше @AfterOpt.
declare @SeniorKassir_RKO_night int = 0 --сколько нехватки оставляем в ночные смены. 0 - на ночь все "дыры" (нехватки человеко-часов) будут закрыты. Используется в пункте III.b


/*****************************************BLOCK BEGIN**********************************************************/
--III.b2 Отдельный расчет для понедельников и воскресений
Print convert(varchar(10),getdate(),102) + ' ' + convert(varchar(8),getdate(),108) + ' Расчет по кассирам аутсорса - субботы и воскресенья'
declare @DateMaxO2ms date = (select max([Дата прогноза]) from #RawData)
declare @DateO2ms date

--Начало цикла
SET @DateO2ms = (select min([Дата прогноза]) from #RawData) --для каждого магазина заново ставим счетчик даты
WHILE @DateO2ms<=@DateMaxO2ms
BEGIN

	--Для понедельника
	IF (@DateO2ms=(select min([Дата прогноза]) from #RawData))
	BEGIN

		--Шаг 1. Суммированиве нехватки кассиров по часам
		IF OBJECT_ID('tempdb..#tSum_O2mond') IS NOT NULL BEGIN DROP TABLE #tSum_O2mond END	
		SELECT [Код магазина],[Дата прогноза]
			,sum(case when time >=0 and time<=7 then [Прогноз кассиров] else 0 end) as FT_22_8 --начало в 22:00, конец в 8:00 
			,max(case when time >=0 and time<=7 then [Прогноз кассиров] else 0 end) as mHour_22_8 --начало в 22:00, конец в 8:00 
		into #tSum_O2mond
		FROM #RawData
		where [Прогноз кассиров]>0
		and [Дата прогноза]=@DateO2ms
		group by [Код магазина], [Дата прогноза]
		--Шаг 2. Определение самой дефицитной по кассирам смены - ставим жестко начало в 22 предыдущего дня, конец в 8 утра понедельника этой недели
		IF OBJECT_ID('tempdb..#tShift_O2mond') IS NOT NULL BEGIN DROP TABLE #tShift_O2mond END	
		select distinct [Код магазина], [Дата прогноза]
			,22 as [Начало смены]
			,8 as [Конец смены]
			, mHour_22_8
		into #tShift_O2mond
		from #tSum_O2mond
		where FT_22_8>0
		
		--Шаг 3. Назначение кассиров в обозначенное время по максимальной нехватке (сколько часов нехватаит по максимуму - столько ставим кассиров)
		UPDATE RD
		SET RD.[Прогноз кассиров] = RD.[Прогноз кассиров] - mHour_22_8
		FROM #RawData RD
		join #tShift_O2mond tS on tS.[Код магазина]=RD.[Код магазина] and tS.[Дата прогноза]=RD.[Дата прогноза]
		where RD.time>=0 and RD.time<=(tS.[Конец смены]-1)
		and ts.[Начало смены] is not null
		
		--Шаг 4. Запись полученной смены (начало, конец, длительность, тип кассира) в таблицу 
		insert into #KassirShort_OutS
		select distinct [Код магазина], dateadd(day,-1,[Дата прогноза]) as [Дата прогноза], 'Outsource' AS [Type], mHour_22_8 as RecNumber
		, [Начало смены] as [TimeStart], [Конец смены] as [TimeEnd]
		, 24-[Начало смены]+[Конец смены] as [WorkingHour], 99 as [Проход]
		from #tShift_O2mond
		where [Начало смены] is not null
		
	END


	--Для воскресенья
	IF (@DateO2ms=(select max([Дата прогноза]) from #RawData))
	BEGIN
		--Шаг 1. Суммированиве нехватки кассиров по часам
		IF OBJECT_ID('tempdb..#tSum_O2_O2sund') IS NOT NULL BEGIN DROP TABLE #tSum_O2_O2sund END	
		SELECT [Код магазина],[Дата прогноза]
			,sum(case when time >=22 and time<=23 then [Прогноз кассиров] else 0 end) as FT_22_8 --начало в 22:00, конец в 8:00 
			,max(case when time >=22 and time<=23 then [Прогноз кассиров] else 0 end) as mHour_22_8 --начало в 22:00, конец в 8:00 
		into #tSum_O2_O2sund
		FROM #RawData
		where [Прогноз кассиров]>0
		and [Дата прогноза]=@DateO2ms
		group by [Код магазина], [Дата прогноза]
		
		--Шаг 2. Определение самой дефицитной по кассирам смены - жестко ставим начало в 22, конец в 8 следующего дня
		IF OBJECT_ID('tempdb..#tShift_O2sund') IS NOT NULL BEGIN DROP TABLE #tShift_O2sund END	
		select [Код магазина], [Дата прогноза]
			,22 as [Начало смены]
			,8 as [Конец смены]
			,mHour_22_8
		into #tShift_O2sund
		from #tSum_O2_O2sund
		where FT_22_8>0
		
		--Шаг 3. Назначение кассира в обозначенное время
		UPDATE RD
		SET RD.[Прогноз кассиров] = RD.[Прогноз кассиров] - mHour_22_8
		FROM #RawData RD
		join #tShift_O2sund tS on tS.[Код магазина]=RD.[Код магазина] and tS.[Дата прогноза]=RD.[Дата прогноза]
		where RD.time>=tS.[Начало смены] and RD.time<=23
		and ts.[Начало смены] is not null
		
		--Шаг 4. Запись полученной смены (начало, конец, длительность, тип кассира) в таблицу 
		insert into #KassirShort_OutS
		select distinct [Код магазина], [Дата прогноза], 'Outsource' AS [Type], mHour_22_8 as RecNumber
		, [Начало смены] as [TimeStart], [Конец смены] as [TimeEnd]
		, 24-[Начало смены]+[Конец смены] as [WorkingHour], 1 as [Проход]
		from #tShift_O2sund
		where [Начало смены] is not null	
	END

SET @DateO2ms = dateadd(day,1,@DateO2ms) --Идем в следующий денб
END
/*****************************************BLOCK END**********************************************************/



/*****************************************BLOCK BEGIN**********************************************************/
--III.с Дневные окна по 8, 9, 10, 11, 12 часов [01:25]
--Долптимизируем дневные смены в мелкой разбивке по часам
Print convert(varchar(10),getdate(),102) + ' ' + convert(varchar(8),getdate(),108) + ' Расчет по кассирам аутсорса - дневные смены по 8,9,10,11,12 чаосв'

--Задание параметров
DECLARE @prohodO3 INT, @ShopIdO3 int, @MaxProhodO3 int, @DateO3 date
DECLARE @MaxShopIdO3 int = (select max([Код магазина]) from #RawData) --Максимльынй код магазина
SET @ShopIdO3 = 1
declare @DateMaxO3 date = (select max([Дата прогноза]) from #RawData)

--Начало цикла
WHILE @ShopIdO3 <= @MaxShopIdO3
BEGIN
SET @DateO3 = (select min([Дата прогноза]) from #RawData) --для каждого магазина заново ставим счетчик даты
	
	WHILE @DateO3<=@DateMaxO3
	BEGIN
	--для каждого магазина и каждой даты находим максимальную нужду кассиров в ночное время
	SET @MaxProhodO3 = (select max([Прогноз кассиров]) from #RawData where [Код магазина]=@ShopIdO3 
						and [Дата прогноза]=@DateO3 and time between 8 and 21 )
	--PRINT 'BEGIN ' + convert(varchar(3),@shopidO3)
	
	IF isnull(@MaxProhodO3,0) >= @SeniorKassir_RKO_day
	BEGIN
	SET @prohodO3 = 1 --для каждого магазина заново ставим счетчик

		WHILE @prohodO3 <= @MaxProhodO3
		BEGIN
				--Шаг 1. Суммирование нужды
				IF OBJECT_ID('tempdb..#tSum_O3') IS NOT NULL BEGIN DROP TABLE #tSum_O3 END	
				--declare @DateO3 date='2015-07-13'
				SELECT [Код магазина],[Дата прогноза]
				  ,sum((case when time >=8 and time<=19 then [Прогноз кассиров] else 0 end)) as FT_8_20 --начало в 08:00, конец в 20:00 
				  ,sum((case when time >=8 and time<=18 then [Прогноз кассиров] else 0 end)) as FT_8_19 --начало в 08:00, конец в 19:00 
				  ,sum((case when time >=8 and time<=17 then [Прогноз кассиров] else 0 end)) as FT_8_18 --начало в 08:00, конец в 18:00 
				  ,sum((case when time >=8 and time<=16 then [Прогноз кассиров] else 0 end)) as FT_8_17 --начало в 08:00, конец в 17:00 
				  ,sum((case when time >=8 and time<=15 then [Прогноз кассиров] else 0 end)) as FT_8_16 --начало в 08:00, конец в 16:00 
				  
				  ,sum((case when time >=9 and time<=20 then [Прогноз кассиров] else 0 end)) as FT_9_21 --начало в 09:00, конец в 21:00 
				  ,sum((case when time >=9 and time<=19 then [Прогноз кассиров] else 0 end)) as FT_9_20 --начало в 09:00, конец в 20:00 
				  ,sum((case when time >=9 and time<=18 then [Прогноз кассиров] else 0 end)) as FT_9_19 --начало в 09:00, конец в 19:00 
				  ,sum((case when time >=9 and time<=17 then [Прогноз кассиров] else 0 end)) as FT_9_18 --начало в 09:00, конец в 18:00 
				  ,sum((case when time >=9 and time<=16 then [Прогноз кассиров] else 0 end)) as FT_9_17 --начало в 09:00, конец в 17:00 
				  
				  ,sum((case when time >=10 and time<=21 then [Прогноз кассиров] else 0 end)) as FT_10_22 --начало в 10:00, конец в 22:00 
				  ,sum((case when time >=10 and time<=20 then [Прогноз кассиров] else 0 end)) as FT_10_21 --начало в 10:00, конец в 21:00 
				  ,sum((case when time >=10 and time<=19 then [Прогноз кассиров] else 0 end)) as FT_10_20 --начало в 10:00, конец в 20:00 
				  ,sum((case when time >=10 and time<=18 then [Прогноз кассиров] else 0 end)) as FT_10_19 --начало в 10:00, конец в 19:00 
				  ,sum((case when time >=10 and time<=17 then [Прогноз кассиров] else 0 end)) as FT_10_18 --начало в 10:00, конец в 18:00 

				  ,sum((case when time >=11 and time<=21 then [Прогноз кассиров] else 0 end)) as FT_11_22 --начало в 11:00, конец в 22:00 
				  ,sum((case when time >=11 and time<=20 then [Прогноз кассиров] else 0 end)) as FT_11_21 --начало в 11:00, конец в 21:00 
				  ,sum((case when time >=11 and time<=19 then [Прогноз кассиров] else 0 end)) as FT_11_20 --начало в 11:00, конец в 20:00 
				  ,sum((case when time >=11 and time<=18 then [Прогноз кассиров] else 0 end)) as FT_11_19 --начало в 11:00, конец в 19:00 
	
				  ,sum((case when time >=12 and time<=21 then [Прогноз кассиров] else 0 end)) as FT_12_22 --начало в 12:00, конец в 22:00 
				  ,sum((case when time >=12 and time<=20 then [Прогноз кассиров] else 0 end)) as FT_12_21 --начало в 12:00, конец в 21:00 
				  ,sum((case when time >=12 and time<=19 then [Прогноз кассиров] else 0 end)) as FT_12_20 --начало в 12:00, конец в 20:00 
				  
				  ,sum((case when time >=13 and time<=21 then [Прогноз кассиров] else 0 end)) as FT_13_22 --начало в 13:00, конец в 22:00 
				  ,sum((case when time >=13 and time<=20 then [Прогноз кассиров] else 0 end)) as FT_13_21 --начало в 13:00, конец в 21:00 
				  
				  ,sum((case when time >=14 and time<=21 then [Прогноз кассиров] else 0 end)) as FT_14_22 --начало в 14:00, конец в 22:00 
				into #tSum_O3
				FROM #RawData
				where [Прогноз кассиров]>0
				and [Дата прогноза]=@DateO3
				group by [Код магазина], [Дата прогноза]
		
		
				--Шаг 2. Выбор самого нуждающегося времени
					--если суммы одинаковые, ставим каиира там, где смена начианется раньше (как бы учитывая пики до их начала)
				IF OBJECT_ID('tempdb..#tShift_O3') IS NOT NULL BEGIN DROP TABLE #tShift_O3 END	
				select distinct [Код магазина],[Дата прогноза]
				, (case 
						when FT_8_20>= FT_8_19 and 	FT_8_20>= FT_8_18 and 	FT_8_20>= FT_8_17 and 	FT_8_20>= FT_8_16 and 	FT_8_20>= FT_9_21 and 	FT_8_20>= FT_9_20 and 	FT_8_20>= FT_9_19 and 	FT_8_20>= FT_9_18 and 	FT_8_20>= FT_9_17 and 	FT_8_20>= FT_10_22 and 	FT_8_20>= FT_10_21 and 	FT_8_20>= FT_10_20 and 	FT_8_20>= FT_10_19 and 	FT_8_20>= FT_10_18 and 	FT_8_20>= FT_11_22 and 	FT_8_20>= FT_11_21 and 	FT_8_20>= FT_11_20 and 	FT_8_20>= FT_11_19 and 	FT_8_20>= FT_12_22 and 	FT_8_20>= FT_12_21 and 	FT_8_20>= FT_12_20 and 	FT_8_20>= FT_13_22 and 	FT_8_20>= FT_13_21 and 	FT_8_20>= FT_14_22  then 8
						when FT_8_20>= FT_8_19 and FT_8_20>= FT_8_18 and FT_8_20>= FT_8_17 and FT_8_20>= FT_8_16 and FT_8_20>= FT_9_21 and FT_8_20>= FT_9_20 and FT_8_20>= FT_9_19 and FT_8_20>= FT_9_18 and FT_8_20>= FT_9_17 and FT_8_20>= FT_10_22 and FT_8_20>= FT_10_21 and FT_8_20>= FT_10_20 and FT_8_20>= FT_10_19 and FT_8_20>= FT_10_18 and FT_8_20>= FT_11_22 and FT_8_20>= FT_11_21 and FT_8_20>= FT_11_20 and FT_8_20>= FT_11_19 and FT_8_20>= FT_12_22 and FT_8_20>= FT_12_21 and FT_8_20>= FT_12_20 and FT_8_20>= FT_13_22 and FT_8_20>= FT_13_21 and FT_8_20>= FT_14_22 then 8
						when FT_8_19>= FT_8_18 and FT_8_19>= FT_8_17 and FT_8_19>= FT_8_16 and FT_8_19>= FT_9_21 and FT_8_19>= FT_9_20 and FT_8_19>= FT_9_19 and FT_8_19>= FT_9_18 and FT_8_19>= FT_9_17 and FT_8_19>= FT_10_22 and FT_8_19>= FT_10_21 and FT_8_19>= FT_10_20 and FT_8_19>= FT_10_19 and FT_8_19>= FT_10_18 and FT_8_19>= FT_11_22 and FT_8_19>= FT_11_21 and FT_8_19>= FT_11_20 and FT_8_19>= FT_11_19 and FT_8_19>= FT_12_22 and FT_8_19>= FT_12_21 and FT_8_19>= FT_12_20 and FT_8_19>= FT_13_22 and FT_8_19>= FT_13_21 and FT_8_19>= FT_14_22 then 8
						when FT_8_18>= FT_8_17 and FT_8_18>= FT_8_16 and FT_8_18>= FT_9_21 and FT_8_18>= FT_9_20 and FT_8_18>= FT_9_19 and FT_8_18>= FT_9_18 and FT_8_18>= FT_9_17 and FT_8_18>= FT_10_22 and FT_8_18>= FT_10_21 and FT_8_18>= FT_10_20 and FT_8_18>= FT_10_19 and FT_8_18>= FT_10_18 and FT_8_18>= FT_11_22 and FT_8_18>= FT_11_21 and FT_8_18>= FT_11_20 and FT_8_18>= FT_11_19 and FT_8_18>= FT_12_22 and FT_8_18>= FT_12_21 and FT_8_18>= FT_12_20 and FT_8_18>= FT_13_22 and FT_8_18>= FT_13_21 and FT_8_18>= FT_14_22 then 8
						when FT_8_17>= FT_8_16 and FT_8_17>= FT_9_21 and FT_8_17>= FT_9_20 and FT_8_17>= FT_9_19 and FT_8_17>= FT_9_18 and FT_8_17>= FT_9_17 and FT_8_17>= FT_10_22 and FT_8_17>= FT_10_21 and FT_8_17>= FT_10_20 and FT_8_17>= FT_10_19 and FT_8_17>= FT_10_18 and FT_8_17>= FT_11_22 and FT_8_17>= FT_11_21 and FT_8_17>= FT_11_20 and FT_8_17>= FT_11_19 and FT_8_17>= FT_12_22 and FT_8_17>= FT_12_21 and FT_8_17>= FT_12_20 and FT_8_17>= FT_13_22 and FT_8_17>= FT_13_21 and FT_8_17>= FT_14_22 then 8
						when FT_8_16>= FT_9_21 and FT_8_16>= FT_9_20 and FT_8_16>= FT_9_19 and FT_8_16>= FT_9_18 and FT_8_16>= FT_9_17 and FT_8_16>= FT_10_22 and FT_8_16>= FT_10_21 and FT_8_16>= FT_10_20 and FT_8_16>= FT_10_19 and FT_8_16>= FT_10_18 and FT_8_16>= FT_11_22 and FT_8_16>= FT_11_21 and FT_8_16>= FT_11_20 and FT_8_16>= FT_11_19 and FT_8_16>= FT_12_22 and FT_8_16>= FT_12_21 and FT_8_16>= FT_12_20 and FT_8_16>= FT_13_22 and FT_8_16>= FT_13_21 and FT_8_16>= FT_14_22 then 8

						when FT_9_21>= FT_9_20 and FT_9_21>= FT_9_19 and FT_9_21>= FT_9_18 and FT_9_21>= FT_9_17 and FT_9_21>= FT_10_22 and FT_9_21>= FT_10_21 and FT_9_21>= FT_10_20 and FT_9_21>= FT_10_19 and FT_9_21>= FT_10_18 and FT_9_21>= FT_11_22 and FT_9_21>= FT_11_21 and FT_9_21>= FT_11_20 and FT_9_21>= FT_11_19 and FT_9_21>= FT_12_22 and FT_9_21>= FT_12_21 and FT_9_21>= FT_12_20 and FT_9_21>= FT_13_22 and FT_9_21>= FT_13_21 and FT_9_21>= FT_14_22 then 9
						when FT_9_20>= FT_9_19 and FT_9_20>= FT_9_18 and FT_9_20>= FT_9_17 and FT_9_20>= FT_10_22 and FT_9_20>= FT_10_21 and FT_9_20>= FT_10_20 and FT_9_20>= FT_10_19 and FT_9_20>= FT_10_18 and FT_9_20>= FT_11_22 and FT_9_20>= FT_11_21 and FT_9_20>= FT_11_20 and FT_9_20>= FT_11_19 and FT_9_20>= FT_12_22 and FT_9_20>= FT_12_21 and FT_9_20>= FT_12_20 and FT_9_20>= FT_13_22 and FT_9_20>= FT_13_21 and FT_9_20>= FT_14_22 then 9
						when FT_9_19>= FT_9_18 and FT_9_19>= FT_9_17 and FT_9_19>= FT_10_22 and FT_9_19>= FT_10_21 and FT_9_19>= FT_10_20 and FT_9_19>= FT_10_19 and FT_9_19>= FT_10_18 and FT_9_19>= FT_11_22 and FT_9_19>= FT_11_21 and FT_9_19>= FT_11_20 and FT_9_19>= FT_11_19 and FT_9_19>= FT_12_22 and FT_9_19>= FT_12_21 and FT_9_19>= FT_12_20 and FT_9_19>= FT_13_22 and FT_9_19>= FT_13_21 and FT_9_19>= FT_14_22 then 9
						when FT_9_18>= FT_9_17 and FT_9_18>= FT_10_22 and FT_9_18>= FT_10_21 and FT_9_18>= FT_10_20 and FT_9_18>= FT_10_19 and FT_9_18>= FT_10_18 and FT_9_18>= FT_11_22 and FT_9_18>= FT_11_21 and FT_9_18>= FT_11_20 and FT_9_18>= FT_11_19 and FT_9_18>= FT_12_22 and FT_9_18>= FT_12_21 and FT_9_18>= FT_12_20 and FT_9_18>= FT_13_22 and FT_9_18>= FT_13_21 and FT_9_18>= FT_14_22 then 9
						when FT_9_17>= FT_10_22 and FT_9_17>= FT_10_21 and FT_9_17>= FT_10_20 and FT_9_17>= FT_10_19 and FT_9_17>= FT_10_18 and FT_9_17>= FT_11_22 and FT_9_17>= FT_11_21 and FT_9_17>= FT_11_20 and FT_9_17>= FT_11_19 and FT_9_17>= FT_12_22 and FT_9_17>= FT_12_21 and FT_9_17>= FT_12_20 and FT_9_17>= FT_13_22 and FT_9_17>= FT_13_21 and FT_9_17>= FT_14_22 then 9

						when FT_10_22>= FT_10_21 and FT_10_22>= FT_10_20 and FT_10_22>= FT_10_19 and FT_10_22>= FT_10_18 and FT_10_22>= FT_11_22 and FT_10_22>= FT_11_21 and FT_10_22>= FT_11_20 and FT_10_22>= FT_11_19 and FT_10_22>= FT_12_22 and FT_10_22>= FT_12_21 and FT_10_22>= FT_12_20 and FT_10_22>= FT_13_22 and FT_10_22>= FT_13_21 and FT_10_22>= FT_14_22 then 10
						when FT_10_21>= FT_10_20 and FT_10_21>= FT_10_19 and FT_10_21>= FT_10_18 and FT_10_21>= FT_11_22 and FT_10_21>= FT_11_21 and FT_10_21>= FT_11_20 and FT_10_21>= FT_11_19 and FT_10_21>= FT_12_22 and FT_10_21>= FT_12_21 and FT_10_21>= FT_12_20 and FT_10_21>= FT_13_22 and FT_10_21>= FT_13_21 and FT_10_21>= FT_14_22 then 10
						when FT_10_20>= FT_10_19 and FT_10_20>= FT_10_18 and FT_10_20>= FT_11_22 and FT_10_20>= FT_11_21 and FT_10_20>= FT_11_20 and FT_10_20>= FT_11_19 and FT_10_20>= FT_12_22 and FT_10_20>= FT_12_21 and FT_10_20>= FT_12_20 and FT_10_20>= FT_13_22 and FT_10_20>= FT_13_21 and FT_10_20>= FT_14_22 then 10
						when FT_10_19>= FT_10_18 and FT_10_19>= FT_11_22 and FT_10_19>= FT_11_21 and FT_10_19>= FT_11_20 and FT_10_19>= FT_11_19 and FT_10_19>= FT_12_22 and FT_10_19>= FT_12_21 and FT_10_19>= FT_12_20 and FT_10_19>= FT_13_22 and FT_10_19>= FT_13_21 and FT_10_19>= FT_14_22 then 10
						when FT_10_18>= FT_11_22 and FT_10_18>= FT_11_21 and FT_10_18>= FT_11_20 and FT_10_18>= FT_11_19 and FT_10_18>= FT_12_22 and FT_10_18>= FT_12_21 and FT_10_18>= FT_12_20 and FT_10_18>= FT_13_22 and FT_10_18>= FT_13_21 and FT_10_18>= FT_14_22 then 10

						when FT_11_22>= FT_11_21 and FT_11_22>= FT_11_20 and FT_11_22>= FT_11_19 and FT_11_22>= FT_12_22 and FT_11_22>= FT_12_21 and FT_11_22>= FT_12_20 and FT_11_22>= FT_13_22 and FT_11_22>= FT_13_21 and FT_11_22>= FT_14_22 then 11
						when FT_11_21>= FT_11_20 and FT_11_21>= FT_11_19 and FT_11_21>= FT_12_22 and FT_11_21>= FT_12_21 and FT_11_21>= FT_12_20 and FT_11_21>= FT_13_22 and FT_11_21>= FT_13_21 and FT_11_21>= FT_14_22 then 11
						when FT_11_20>= FT_11_19 and FT_11_20>= FT_12_22 and FT_11_20>= FT_12_21 and FT_11_20>= FT_12_20 and FT_11_20>= FT_13_22 and FT_11_20>= FT_13_21 and FT_11_20>= FT_14_22 then 11
						when FT_11_19>= FT_12_22 and FT_11_19>= FT_12_21 and FT_11_19>= FT_12_20 and FT_11_19>= FT_13_22 and FT_11_19>= FT_13_21 and FT_11_19>= FT_14_22 then 11

						when FT_12_22>= FT_12_21 and FT_12_22>= FT_12_20 and FT_12_22>= FT_13_22 and FT_12_22>= FT_13_21 and FT_12_22>= FT_14_22 then 12
						when FT_12_21>= FT_12_20 and FT_12_21>= FT_13_22 and FT_12_21>= FT_13_21 and FT_12_21>= FT_14_22 then 12
						when FT_12_20>= FT_13_22 and FT_12_20>= FT_13_21 and FT_12_20>= FT_14_22 then 12

						when FT_13_22>= FT_13_21 and FT_13_22>= FT_14_22 then 13
						when FT_13_21>= FT_14_22 then 13
					end) as [Начало смены]
				, (case 
						when FT_8_20>= FT_8_19 and 	FT_8_20>= FT_8_18 and 	FT_8_20>= FT_8_17 and 	FT_8_20>= FT_8_16 and 	FT_8_20>= FT_9_21 and 	FT_8_20>= FT_9_20 and 	FT_8_20>= FT_9_19 and 	FT_8_20>= FT_9_18 and 	FT_8_20>= FT_9_17 and 	FT_8_20>= FT_10_22 and 	FT_8_20>= FT_10_21 and 	FT_8_20>= FT_10_20 and 	FT_8_20>= FT_10_19 and 	FT_8_20>= FT_10_18 and 	FT_8_20>= FT_11_22 and 	FT_8_20>= FT_11_21 and 	FT_8_20>= FT_11_20 and 	FT_8_20>= FT_11_19 and 	FT_8_20>= FT_12_22 and 	FT_8_20>= FT_12_21 and 	FT_8_20>= FT_12_20 and 	FT_8_20>= FT_13_22 and 	FT_8_20>= FT_13_21 and 	FT_8_20>= FT_14_22  then 20
						when FT_8_20>= FT_8_19 and FT_8_20>= FT_8_18 and FT_8_20>= FT_8_17 and FT_8_20>= FT_8_16 and FT_8_20>= FT_9_21 and FT_8_20>= FT_9_20 and FT_8_20>= FT_9_19 and FT_8_20>= FT_9_18 and FT_8_20>= FT_9_17 and FT_8_20>= FT_10_22 and FT_8_20>= FT_10_21 and FT_8_20>= FT_10_20 and FT_8_20>= FT_10_19 and FT_8_20>= FT_10_18 and FT_8_20>= FT_11_22 and FT_8_20>= FT_11_21 and FT_8_20>= FT_11_20 and FT_8_20>= FT_11_19 and FT_8_20>= FT_12_22 and FT_8_20>= FT_12_21 and FT_8_20>= FT_12_20 and FT_8_20>= FT_13_22 and FT_8_20>= FT_13_21 and FT_8_20>= FT_14_22 then 20
						when FT_8_19>= FT_8_18 and FT_8_19>= FT_8_17 and FT_8_19>= FT_8_16 and FT_8_19>= FT_9_21 and FT_8_19>= FT_9_20 and FT_8_19>= FT_9_19 and FT_8_19>= FT_9_18 and FT_8_19>= FT_9_17 and FT_8_19>= FT_10_22 and FT_8_19>= FT_10_21 and FT_8_19>= FT_10_20 and FT_8_19>= FT_10_19 and FT_8_19>= FT_10_18 and FT_8_19>= FT_11_22 and FT_8_19>= FT_11_21 and FT_8_19>= FT_11_20 and FT_8_19>= FT_11_19 and FT_8_19>= FT_12_22 and FT_8_19>= FT_12_21 and FT_8_19>= FT_12_20 and FT_8_19>= FT_13_22 and FT_8_19>= FT_13_21 and FT_8_19>= FT_14_22 then 19
						when FT_8_18>= FT_8_17 and FT_8_18>= FT_8_16 and FT_8_18>= FT_9_21 and FT_8_18>= FT_9_20 and FT_8_18>= FT_9_19 and FT_8_18>= FT_9_18 and FT_8_18>= FT_9_17 and FT_8_18>= FT_10_22 and FT_8_18>= FT_10_21 and FT_8_18>= FT_10_20 and FT_8_18>= FT_10_19 and FT_8_18>= FT_10_18 and FT_8_18>= FT_11_22 and FT_8_18>= FT_11_21 and FT_8_18>= FT_11_20 and FT_8_18>= FT_11_19 and FT_8_18>= FT_12_22 and FT_8_18>= FT_12_21 and FT_8_18>= FT_12_20 and FT_8_18>= FT_13_22 and FT_8_18>= FT_13_21 and FT_8_18>= FT_14_22 then 18
						when FT_8_17>= FT_8_16 and FT_8_17>= FT_9_21 and FT_8_17>= FT_9_20 and FT_8_17>= FT_9_19 and FT_8_17>= FT_9_18 and FT_8_17>= FT_9_17 and FT_8_17>= FT_10_22 and FT_8_17>= FT_10_21 and FT_8_17>= FT_10_20 and FT_8_17>= FT_10_19 and FT_8_17>= FT_10_18 and FT_8_17>= FT_11_22 and FT_8_17>= FT_11_21 and FT_8_17>= FT_11_20 and FT_8_17>= FT_11_19 and FT_8_17>= FT_12_22 and FT_8_17>= FT_12_21 and FT_8_17>= FT_12_20 and FT_8_17>= FT_13_22 and FT_8_17>= FT_13_21 and FT_8_17>= FT_14_22 then 17
						when FT_8_16>= FT_9_21 and FT_8_16>= FT_9_20 and FT_8_16>= FT_9_19 and FT_8_16>= FT_9_18 and FT_8_16>= FT_9_17 and FT_8_16>= FT_10_22 and FT_8_16>= FT_10_21 and FT_8_16>= FT_10_20 and FT_8_16>= FT_10_19 and FT_8_16>= FT_10_18 and FT_8_16>= FT_11_22 and FT_8_16>= FT_11_21 and FT_8_16>= FT_11_20 and FT_8_16>= FT_11_19 and FT_8_16>= FT_12_22 and FT_8_16>= FT_12_21 and FT_8_16>= FT_12_20 and FT_8_16>= FT_13_22 and FT_8_16>= FT_13_21 and FT_8_16>= FT_14_22 then 16

						when FT_9_21>= FT_9_20 and FT_9_21>= FT_9_19 and FT_9_21>= FT_9_18 and FT_9_21>= FT_9_17 and FT_9_21>= FT_10_22 and FT_9_21>= FT_10_21 and FT_9_21>= FT_10_20 and FT_9_21>= FT_10_19 and FT_9_21>= FT_10_18 and FT_9_21>= FT_11_22 and FT_9_21>= FT_11_21 and FT_9_21>= FT_11_20 and FT_9_21>= FT_11_19 and FT_9_21>= FT_12_22 and FT_9_21>= FT_12_21 and FT_9_21>= FT_12_20 and FT_9_21>= FT_13_22 and FT_9_21>= FT_13_21 and FT_9_21>= FT_14_22 then 21
						when FT_9_20>= FT_9_19 and FT_9_20>= FT_9_18 and FT_9_20>= FT_9_17 and FT_9_20>= FT_10_22 and FT_9_20>= FT_10_21 and FT_9_20>= FT_10_20 and FT_9_20>= FT_10_19 and FT_9_20>= FT_10_18 and FT_9_20>= FT_11_22 and FT_9_20>= FT_11_21 and FT_9_20>= FT_11_20 and FT_9_20>= FT_11_19 and FT_9_20>= FT_12_22 and FT_9_20>= FT_12_21 and FT_9_20>= FT_12_20 and FT_9_20>= FT_13_22 and FT_9_20>= FT_13_21 and FT_9_20>= FT_14_22 then 20
						when FT_9_19>= FT_9_18 and FT_9_19>= FT_9_17 and FT_9_19>= FT_10_22 and FT_9_19>= FT_10_21 and FT_9_19>= FT_10_20 and FT_9_19>= FT_10_19 and FT_9_19>= FT_10_18 and FT_9_19>= FT_11_22 and FT_9_19>= FT_11_21 and FT_9_19>= FT_11_20 and FT_9_19>= FT_11_19 and FT_9_19>= FT_12_22 and FT_9_19>= FT_12_21 and FT_9_19>= FT_12_20 and FT_9_19>= FT_13_22 and FT_9_19>= FT_13_21 and FT_9_19>= FT_14_22 then 19
						when FT_9_18>= FT_9_17 and FT_9_18>= FT_10_22 and FT_9_18>= FT_10_21 and FT_9_18>= FT_10_20 and FT_9_18>= FT_10_19 and FT_9_18>= FT_10_18 and FT_9_18>= FT_11_22 and FT_9_18>= FT_11_21 and FT_9_18>= FT_11_20 and FT_9_18>= FT_11_19 and FT_9_18>= FT_12_22 and FT_9_18>= FT_12_21 and FT_9_18>= FT_12_20 and FT_9_18>= FT_13_22 and FT_9_18>= FT_13_21 and FT_9_18>= FT_14_22 then 18
						when FT_9_17>= FT_10_22 and FT_9_17>= FT_10_21 and FT_9_17>= FT_10_20 and FT_9_17>= FT_10_19 and FT_9_17>= FT_10_18 and FT_9_17>= FT_11_22 and FT_9_17>= FT_11_21 and FT_9_17>= FT_11_20 and FT_9_17>= FT_11_19 and FT_9_17>= FT_12_22 and FT_9_17>= FT_12_21 and FT_9_17>= FT_12_20 and FT_9_17>= FT_13_22 and FT_9_17>= FT_13_21 and FT_9_17>= FT_14_22 then 17

						when FT_10_22>= FT_10_21 and FT_10_22>= FT_10_20 and FT_10_22>= FT_10_19 and FT_10_22>= FT_10_18 and FT_10_22>= FT_11_22 and FT_10_22>= FT_11_21 and FT_10_22>= FT_11_20 and FT_10_22>= FT_11_19 and FT_10_22>= FT_12_22 and FT_10_22>= FT_12_21 and FT_10_22>= FT_12_20 and FT_10_22>= FT_13_22 and FT_10_22>= FT_13_21 and FT_10_22>= FT_14_22 then 22
						when FT_10_21>= FT_10_20 and FT_10_21>= FT_10_19 and FT_10_21>= FT_10_18 and FT_10_21>= FT_11_22 and FT_10_21>= FT_11_21 and FT_10_21>= FT_11_20 and FT_10_21>= FT_11_19 and FT_10_21>= FT_12_22 and FT_10_21>= FT_12_21 and FT_10_21>= FT_12_20 and FT_10_21>= FT_13_22 and FT_10_21>= FT_13_21 and FT_10_21>= FT_14_22 then 21
						when FT_10_20>= FT_10_19 and FT_10_20>= FT_10_18 and FT_10_20>= FT_11_22 and FT_10_20>= FT_11_21 and FT_10_20>= FT_11_20 and FT_10_20>= FT_11_19 and FT_10_20>= FT_12_22 and FT_10_20>= FT_12_21 and FT_10_20>= FT_12_20 and FT_10_20>= FT_13_22 and FT_10_20>= FT_13_21 and FT_10_20>= FT_14_22 then 20
						when FT_10_19>= FT_10_18 and FT_10_19>= FT_11_22 and FT_10_19>= FT_11_21 and FT_10_19>= FT_11_20 and FT_10_19>= FT_11_19 and FT_10_19>= FT_12_22 and FT_10_19>= FT_12_21 and FT_10_19>= FT_12_20 and FT_10_19>= FT_13_22 and FT_10_19>= FT_13_21 and FT_10_19>= FT_14_22 then 19
						when FT_10_18>= FT_11_22 and FT_10_18>= FT_11_21 and FT_10_18>= FT_11_20 and FT_10_18>= FT_11_19 and FT_10_18>= FT_12_22 and FT_10_18>= FT_12_21 and FT_10_18>= FT_12_20 and FT_10_18>= FT_13_22 and FT_10_18>= FT_13_21 and FT_10_18>= FT_14_22 then 18

						when FT_11_22>= FT_11_21 and FT_11_22>= FT_11_20 and FT_11_22>= FT_11_19 and FT_11_22>= FT_12_22 and FT_11_22>= FT_12_21 and FT_11_22>= FT_12_20 and FT_11_22>= FT_13_22 and FT_11_22>= FT_13_21 and FT_11_22>= FT_14_22 then 22
						when FT_11_21>= FT_11_20 and FT_11_21>= FT_11_19 and FT_11_21>= FT_12_22 and FT_11_21>= FT_12_21 and FT_11_21>= FT_12_20 and FT_11_21>= FT_13_22 and FT_11_21>= FT_13_21 and FT_11_21>= FT_14_22 then 21
						when FT_11_20>= FT_11_19 and FT_11_20>= FT_12_22 and FT_11_20>= FT_12_21 and FT_11_20>= FT_12_20 and FT_11_20>= FT_13_22 and FT_11_20>= FT_13_21 and FT_11_20>= FT_14_22 then 20
						when FT_11_19>= FT_12_22 and FT_11_19>= FT_12_21 and FT_11_19>= FT_12_20 and FT_11_19>= FT_13_22 and FT_11_19>= FT_13_21 and FT_11_19>= FT_14_22 then 19

						when FT_12_22>= FT_12_21 and FT_12_22>= FT_12_20 and FT_12_22>= FT_13_22 and FT_12_22>= FT_13_21 and FT_12_22>= FT_14_22 then 22
						when FT_12_21>= FT_12_20 and FT_12_21>= FT_13_22 and FT_12_21>= FT_13_21 and FT_12_21>= FT_14_22 then 21
						when FT_12_20>= FT_13_22 and FT_12_20>= FT_13_21 and FT_12_20>= FT_14_22 then 20

						when FT_13_22>= FT_13_21 and FT_13_22>= FT_14_22 then 22
						when FT_13_21>= FT_14_22 then 21
					end) as [Конец смены]
				into #tShift_O3
				from #tSum_O3
				
				
				--Шаг 3. Назначение кассира в обозначенное время
				UPDATE RD
				SET RD.[Прогноз кассиров] = RD.[Прогноз кассиров] - 1
				FROM #RawData RD
				join #tShift_O3 tS on tS.[Код магазина]=RD.[Код магазина] and tS.[Дата прогноза]=RD.[Дата прогноза]
				where RD.time>=tS.[Начало смены] and RD.time<=(tS.[Конец смены]-1)
				and ts.[Начало смены] is not null

				--select RD.[Код магазина], RD.[Дата прогноза], RD.[День недели], RD.time, RD.[Диапазон времени]
				--, RD.[Кассиров из ШР]
				--, RD.[Прогноз кассиров]
				--, tS.[Начало смены]
				--, (case when RD.time>=tS.[Начало смены] and RD.time<=(tS.[Начало смены]+11) then 0 end) as typ
				--FROM #RawData RD
				--join #tShift_O3 tS on tS.[Код магазина]=RD.[Код магазина] and tS.[Дата прогноза]=RD.[Дата прогноза]
				--where RD.time>=tS.[Начало смены] and RD.time<=(tS.[Начало смены]+11)
				--order by RD.[Код магазина] , RD.[Дата прогноза], RD.time

				--Шаг 4. Запись полученной смены (начало, конец, длительность, тип кассира) в таблицу 
				insert into #KassirShort_OutS
				select distinct [Код магазина], [Дата прогноза], 'Outsource' AS [Type], 1 as RecNumber, [Начало смены] as [TimeStart]
				, [Конец смены] as [TimeEnd], [Конец смены]-[Начало смены] as [WorkingHour], @prohodO3 as [Проход]
				from #tShift_O3
				where [Начало смены] is not null
				
			SET @prohodO3 = @prohodO3 + 1 --идем в следующий проход до @MaxProhod
			END
			--PRINT 'DONE ' + convert(varchar(3),@prohodO3)
			
		END
		--PRINT 'DONE ' + convert(varchar(10),@DateO3)
	
	SET @DateO3 = dateadd(day,1,@DateO3) --Идем в следующий денб
	END
	--PRINT 'DONE SHOP'  + convert(varchar(3),@shopidO3)

SET @ShopIdO3 = @ShopIdO3 + 1 --идем в следующий магазин до @MaxShopId
END
--PRINT 'Done FOR LOOP Outsource Day'
--GO
/*****************************************BLOCK END**********************************************************/


/* IV. Экспорт данных в таблицы SQL-STORE */
/*****************************************BLOCK BEGIN**********************************************************/
set datefirst 1

Declare @MaxTask int = (select MAX([Номер задания]) from FrontStore.dbo.KassirReportTask)

--insert into FrontStore.dbo.KassirReportShort
select @MaxTask+1 as [Номер задания], t1.shopid as [Код магазина], ES.ShopName as [Магазин], date as [Дата прогноза], Type as [Тип кассира]
	,(case when datepart(dw,date) in (1,2,5,6) then 1 else 2 end) as [Смена]
	, sum(RecNumber) as [Рекомендация кассиров в смену], TimeStart as [Время начала смены]
	, TimeEnd as [Время окончания смены], WorkingHour as [Длительность смены]
--into FrontStore.dbo.KassirReportShort
from 
(select * from #KassirShort_OutS
union all
select * from #KassirShort) t1
join Backstore.dbo.EntShops ES on ES.ShopiD=t1.ShopId
--where t1.shopid in (5, 7, 8, 16, 91, 128) 
group by t1.shopid, date, Type, TimeStart, TimeEnd, WorkingHour, ES.ShopName


--insert into FrontStore.dbo.KassirReportLong
select @MaxTask+1 as [Номер задания], [Код магазина], ES.ShopName as [Магазин], [Дата прогноза], [День недели], time, [Диапазон времени] as [Время работы]
, [Кассиров из ШР] as [Людей в смене, всего]
, [Прогноз кассиров Исходный] as [Исходная рекомендация]
, [Прогноз кассиров Исходный] - [Прогноз кассиров] as [Рекомендация после распределения по сменам]
, [Прогноз кассиров] as [Излишек \ недостаток после распределения по сменам]
--, MaxKassir, FactKassir 
, Неявки
--into FrontStore.dbo.KassirReportLong
from #RawData t1
join Backstore.dbo.EntShops ES on ES.ShopiD=t1.[Код магазина]
--where [Код магазина] in (5, 7, 8, 16, 91, 128) 


--insert into FrontStore.dbo.KassirReportTask
select GETDATE() as [Дата расчета], @MaxTask+1 as [Номер задания], @K as K
, (select min([Дата прогноза]) from #RawData) as [Дата прогноза с]
, (select max([Дата прогноза]) from #RawData) as [Дата прогноза по]
--into FrontStore.dbo.KassirReportTask

Print convert(varchar(10),getdate(),102) + ' ' + convert(varchar(8),getdate(),108) + ' Расчет завершен'
/*****************************************BLOCK END**********************************************************/


/* V. Проверки */
/*****************************************BLOCK BEGIN**********************************************************/
/*
--select * from #Recomendations
--where [Код магазина] in (5, 7, 8, 16 ,91, 128)
--order by [Код магазина], [Дата базы], time

--select * from #KassirShort_OutS
--where workinghour<12
--order by shopid, Проход, date

--select * from #RawData
--where 
----not (time between 0 and 7) and not (time between 22 and 23)
--  [Прогноз кассиров]=1
--order by [Код магазина], [Дата прогноза], time

--select * from #RawData
----where [Код магазина]=3
--order by [Код магазина], [Дата прогноза], time

--select * from #KassirShort_OutS
--where shopid=3
--order by shopid, date, timeStart
*/
/*****************************************BLOCK END**********************************************************/



