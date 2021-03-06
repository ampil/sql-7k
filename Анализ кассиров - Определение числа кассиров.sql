/*Таблица с потоком в магазинах*/

/*Запуск с SQL-STOR*/

--Чеки с позициями
IF OBJECT_ID('tempdb..#BillsPositions') IS NOT NULL BEGIN DROP TABLE #BillsPositions Print 'Deleted #BillsPositions' END	

SELECT 
	convert(date,t1.[DateOpen]) as Date
	,t1.[ShopId]
	,[ShopShiftId]
	,t1.[ShiftId]
	,[Shift]
	,t1.[LogicalNumber] as [Номер кассы]
	--,t6.Comment
	--,[FRNumber]
	
	,t1.[DateOpen] as [Смена открыта]
	,t1.[DateClose] as [Смена закрыта]
	,datediff(minute,t1.DateOpen,t1.DateClose) as ShiftLenMin
	
	,t2.NumberId
	,t7.[Position]
	--,ROW_NUMBER() over (PARTITION BY t1.ShopId, t2.PersonId, t2.NumberId ORDER BY t7.[DateEnter]) AS [№ товара п/п]
	,t7.BillDetailId
	,t7.ItemId
	,t7.Qty
	,t7.Price
	
	,t2.DateOpen as [Чек открыт]
	,t7.[DateEnter]
	,t2.DateClose as [Чек закрыт] 
	,datediff(second,t2.DateOpen,t2.DateClose) as SessionLenSec
	--,t8.DateClose
	,t2.Number as [Номер чека по п\п]
	,t2.Summ as [Сумма брутто]
	,t2.Profit as [Сумма нетто - с учетом округлений и скидок]
	
	----,t2.State
	----,t3.NameRus
	----,t2.Type
	----,t4.Name
	,t2.PersonId
	--,t5.LastName
into #BillsPositions
FROM [FrontStore].[dbo].[BillShifts] t1
join [FrontStore].[dbo].[BillHeaders] t2 on t2.ShiftId=t1.ShiftId
--left join [FrontStore].[dbo].[BillStates] t3 on t2.State=t3.BillStateId
--left join [FrontStore].[dbo].[PaymentTypes] t4 on t4.PaymentTypeId=t2.Type
--left join [FrontStore].[dbo].[Persons] t5 on t5.PersonId=t2.PersonId and t5.ShopId=t1.ShopId
--left join [FrontStore].[dbo].[CashRegisters] t6 on t6.[LogicalNumber]=t1.[LogicalNumber] and t6.ShopId=t1.ShopId
left join [FrontStore].[dbo].[BillDetails] t7 on t7.NumberId=t2.NumberId
where t1.[DateOpen]>='2015-04-01'
	--and t1.ShopId=116
	--and t2.Summ<>t2.Profit
order by t1.ShopId, t1.[DateOpen] desc, t1.ShiftId, t1.Shift, t1.LogicalNumber,t2.NumberId, t7.[DateEnter]


/*
--Просто чеки
IF OBJECT_ID('tempdb..#Bills') IS NOT NULL BEGIN DROP TABLE #Bills Print 'Deleted #Bills' END	

SELECT TOP 300 
	convert(date,t1.[DateOpen]) as Date
	,t1.[ShopId]
	,[ShopShiftId]
	,t1.[ShiftId]
	,[Shift]
	,t1.[LogicalNumber] as [Номер кассы]
	,t6.Comment
	--,[FRNumber]
	
	,t1.[DateOpen] as [Смена открыта]
	,t1.[DateClose] as [Смена закрыта]
	,datediff(minute,t1.DateOpen,t1.DateClose) as ShiftLenMin
	
	,t2.NumberId
	
	,t2.DateOpen as [Чек открыт]
	,t7.[DateEnter]
	,t2.DateClose as [Чек закрыт] 
	
	,datediff(second,t2.DateOpen,t2.DateClose) as SessionLenSec
	--,t8.DateClose
	,t2.Number as [Номер чека по п\п]
	,t2.Summ as [Сумма брутто]
	,t2.Profit as [Сумма нетто - с учетом округлений и скидок]
	
	--,t2.State
	--,t3.NameRus
	--,t2.Type
	--,t4.Name
	,t2.PersonId
	,t5.LastName
	
--into #Bills
FROM [FrontStore].[dbo].[BillShifts] t1
join [FrontStore].[dbo].[BillHeaders] t2 on t2.ShiftId=t1.ShiftId
left join [FrontStore].[dbo].[BillStates] t3 on t2.State=t3.BillStateId
left join [FrontStore].[dbo].[PaymentTypes] t4 on t4.PaymentTypeId=t2.Type
left join [FrontStore].[dbo].[Persons] t5 on t5.PersonId=t2.PersonId and t5.ShopId=t1.ShopId
left join [FrontStore].[dbo].[CashRegisters] t6 on t6.[LogicalNumber]=t1.[LogicalNumber] and t6.ShopId=t1.ShopId
left join [FrontStore].[dbo].[BillDetails] t7 on t7.NumberId=t2.NumberId
where convert(date,t1.[DateOpen])>='2015-04-13'
	--and t1.ShopId=116
	--and t2.Summ<>t2.Profit
order by t1.ShopId, t1.[DateOpen] desc, t1.ShiftId, t1.Shift, t1.LogicalNumber,t2.NumberId
*/


/*create table spsssql.Forecast.dbo.Cashiers (
	ShopId INT, Date date, Month int
	,PersonId int
	,BillsCount int
	,SessionLenSecSum int
	,[BillSpeed, sec] float
	,BillPositions float
	,[TradeArea] float
	,[TotalArea] float
)*/
/*
select top 100 * from #BillsPositions
delete from spsssql.Forecast.dbo.Cashiers
--select * from #Bills
insert into spsssql.Forecast.dbo.Cashiers
select d1.ShopId, d1.Date, d1.Month
		,d1.PersonId
		,d1.BillsCount
		,d1.SessionLenSecSum
		,(case when d1.BillsCount=0 then 0 else d1.SessionLenSecSum*1.0/d1.BillsCount end) as [BillSpeed, sec]
		,d2.BillPositions
		,ES.[TradeArea]
		,ES.[TotalArea]
		--, avg(d1.SessionLenHoursNet) as SessionLenHoursNetAvg
		--, avg(d1.BillsCount*1.0) as BillsCountAvg
from
	(
	--Кол-во обслуженных чеков и время обслуживания чеков одним КАССИРОМ
	select t1.[ShopId], t1.Date, month(t1.Date) as Month
			,t1.PersonId
			,count(NumberId) as BillsCount
			,sum(SessionLenSec) as SessionLenSecSum			
			,count(NumberId)*30.0/3600 as ErrorHours --30 сек ошибка сессии из-за округления в любую (?) сторону
	from #BillsPositions t1
	group by t1.[ShopId], t1.Date, t1.PersonId--, t1.[Смена открыта], t1.[Смена закрыта]
	--order by t1.[ShopId], t1.Date, t1.PersonId--, t1.[Смена открыта]
	) d1
join 
	(
	--Кол-во товаров в одном чеке
	select z1.[ShopId], z1.Date, z1.PersonId, avg(BillsCountPositions*1.0) as BillPositions
	from
		(
		select t1.[ShopId], t1.Date, t1.PersonId, t1.NumberId
				,count(ItemId) as BillsCountPositions
		from #BillsPositions t1
		group by t1.[ShopId], t1.Date, t1.PersonId, t1.NumberId
		) z1
	group by z1.[ShopId], z1.Date, z1.PersonId
	) d2
on d2.Shopid=d1.Shopid and d2.PersonId=d1.PersonId and d2.Date=d1.Date
left join [BackStore].[dbo].[EntShops] ES on ES.Shopid=d1.shopid
--group by d1.ShopId, d1.Month
Order by d1.Month, d1.Shopid
*/





/*Первая группировака*/
--Первое представление
--Кол-во обслуженных чеков и время обслуживания чеков одним КАССИРОМ
IF OBJECT_ID('tempdb..#Bills_1') IS NOT NULL BEGIN DROP TABLE #Bills_1 Print 'Deleted #Bills_1' END	

select t1.[ShopId], convert(date,t1.[Чек открыт]) as Date, month(t1.[Чек открыт]) as Month
		,t1.PersonId
		,t1.NumberId
		,t1.[Номер чека по п\п]
		,datepart(hour,[Чек открыт]) as TimeZone
		,max(Position) as PositionsInBill
		,SessionLenSec
		,[Сумма брутто]
into #Bills_1
from #BillsPositions t1
group by t1.[ShopId], convert(date,t1.[Чек открыт])
		, month(t1.[Чек открыт])
		,t1.PersonId
		,t1.NumberId
		,t1.[Номер чека по п\п]
		,SessionLenSec
		,[Сумма брутто]
		,datepart(hour,[Чек открыт])

--Проверки
select count(*) as 'SessionLenSec<=5' from #Bills_1
where SessionLenSec<=5 
--примерно 17-20% данных использовать нельзя: либо <=0, либо до 5 сек на обслуживание.
--Причина - нет секунд/ окргуление времени до минут
select count(*) as 'SessionLenSec>5' from #Bills_1
where SessionLenSec>5	


select * from #BillsPositions
where shopid=6
and convert(time,[Чек открыт])  between '14:00:00' and '17:00:00' 
--and convert(time,[Чек открыт]) >= '14:00:00' and convert(time,[Чек открыт])<='17:00:00' 


select * from #Bills_1
where shopid=6
and TimeZone between 14 and 17









--Выводная таблица - 1
IF OBJECT_ID('tempdb..#BillsPos_1') IS NOT NULL BEGIN DROP TABLE #BillsPos_1 Print 'Deleted #BillsPos_1' END	
set datefirst 1

select d1.ShopId, d1.Month, d1.WeekNum, TimeZone
		, avg(d1.[Кол-во чеков в TZ]*1.0) as [Чеков в час (среднее)]
into #BillsPos_1
from
	(
	select ShopId, PersonId, Month, Date,DATEPART(dw,Date) as WeekNum 
			, TimeZone, count([Номер чека по п\п]) as [Кол-во чеков в TZ] 
	from #Bills_1
	where SessionLenSec>5
	group by ShopId, PersonId, Month, Date,DATEPART(dw,Date), TimeZone
	) d1
--where d1.ShopId in (6,7,22,236, 263)
group by d1.ShopId, d1.Month, d1.WeekNum, TimeZone
order by d1.ShopId, d1.Month, d1.WeekNum, TimeZone



select date 
from #BillsPos_2
where DATEPART(wk, '2014-04-17') = DATEPART(wk, date)
group by date

--Выводная таблица - 2
--Время обработки одной позиции
IF OBJECT_ID('tempdb..#BillsPos_2') IS NOT NULL BEGIN DROP TABLE #BillsPos_2 Print 'Deleted #BillsPos_2' END	
select t1.ShopId, t1.PersonId, convert(date,t1.DateEnter) as Date
		,t1.NumberId
		,t1.[Номер чека по п\п]
		,t2.DateEnter as [From]
		,t1.DateEnter as [To]
		,datediff(millisecond,t2.DateEnter,t1.DateEnter) as diffmSec
		--,t1.Position
		,t2.Position --сколько пробивается 22 позиция, например
		,t1.[Чек закрыт]
		,t3.LastPosition
		,(case when t3.LastPosition=t1.Position then 1 else 0 end) as bin
into #BillsPos_2
from #BillsPositions t1
left join #BillsPositions t2 on t2.Shopid=t1.Shopid and convert(date,t1.DateEnter)=convert(date,t2.DateEnter) and t1.PersonId=t2.PersonId
								and t1.NumberId=t2.NumberId and t1.Position=t2.Position+1
left join 
	(
	select t1.ShopId, t1.PersonId, convert(date,t1.DateEnter) as Date
		,t1.NumberId
		,max(t1.Position) as LastPosition
	from #BillsPositions t1
	group by t1.ShopId, t1.PersonId, convert(date,t1.DateEnter),t1.NumberId
	) t3
on t3.ShopId=t1.ShopId and t3.PersonId=t1.PersonId and t3.NumberId=t1.NumberId
where t1.SessionLenSec>0
	--and t3.LastPosition=t1.Position



/*Мой результат*/
select avg(diffmSec*1.0)/1000 as diffSec --Скорость обработки позиции
		,avg(LastPosition*1.0) as Positions --кол-во позиций в чеке
		,avg(diffmSec*1.0)/1000 * avg(LastPosition*1.0) as SessinLen
from #BillsPos_2
	--Результаты разных подходов примерно сходятся
select avg(SessionLenSec*1.0) as SessinLen --скорость обработки человека
from #Bills_1

--Чеков в месяц
select v.shopid, avg(BillsPerPerson*1.0) as BillsPerPersonDay
from
	(
	select shopid , date, personid, max([Номер чека по п\п]) as BillsPerPerson
	from #Bills_1
	group by shopid , date, personid
	) v
group by v.shopid

--Кол-во касс в каждый час
select t1.shopid,t1.Hour, avg([Номер кассы]) as Касс
from
	(
	select shopid, date, datepart(hour,[DateEnter]) as Hour, [Номер кассы]
	from #BillsPositions
	group by shopid, date, datepart(hour,[DateEnter]), [Номер кассы]
	) t1
group by t1.shopid,t1.Hour





--Вместе
select t1.shopid
		,t2.Hour
		,t1.BillsPerPersonDay 
		,20 as B
		,t2.Positions as e
		,t2.diffSec as b
		,convert(decimal(24,0), BillsPerPersonDay* (20 + t2.Positions*t2.diffSec)/3600*0.7)  as FormulaDay
		,t3.Касс
		, (convert(decimal(24,0), BillsPerPersonDay* (20 + t2.Positions*t2.diffSec)/3600*0.7) - t3.Касс)/t3.Касс as [Процент разницы]
from
	(
	select v.shopid, v.TimeZone as Hour, avg(BillsPerPerson*1.0) as BillsPerPersonDay
	from
		(
		select shopid , date, personid, TimeZone, max([Номер чека по п\п]) as BillsPerPerson
		from #Bills_1
		group by shopid , date, personid, TimeZone
		) v
	group by v.shopid, v.TimeZone
	) t1
full outer join
	(
	select shopid
			,datepart(hour,[To]) as Hour
			,avg(diffmSec*1.0)/1000 as diffSec --Скорость обработки позиции
			,avg(LastPosition*1.0) as Positions --кол-во позиций в чеке
			,avg(diffmSec*1.0)/1000 * avg(LastPosition*1.0) as SessinLen
			
	from #BillsPos_2
	group by shopid, datepart(hour,[To])
	) t2
on t1.shopid=t2.shopid and t2.Hour=t1.Hour
full outer join
	(
	--Кол-во касс в каждый час
	select t1.shopid,t1.Hour, avg([Номер кассы]) as Касс
	from
		(
		select shopid, date, datepart(hour,[DateEnter]) as Hour, [Номер кассы]
		from #BillsPositions
		group by shopid, date, datepart(hour,[DateEnter]), [Номер кассы]
		) t1
	group by t1.shopid,t1.Hour
	) t3
on t1.shopid=t3.shopid and t3.Hour=t2.Hour
where t1.shopid is not null
order by t1.shopid, t2.Hour






/*Код Алексея*/
SELECT datepart(hour,[BillHeaders].DateClose),COUNT(*)
FROM [dbo].[BillHeaders] (nolock)
join dbo.BillShifts (nolock) on BillShifts.ShiftId=[BillHeaders].ShiftId
where CAST(BillShifts.DateClose as DATE) between '20150413' and '20150419' and ShopId=103
group by datepart(hour,[BillHeaders].DateClose)
order by 1 asc 





join 
	(
	--Кол-во товаров в одном чеке
	select z1.[ShopId], z1.Date, z1.PersonId, avg(BillsCountPositions*1.0) as BillPositions
	from
		(
		select t1.[ShopId], t1.Date, t1.PersonId, t1.NumberId
				,count(ItemId) as BillsCountPositions
		from #BillsPositions t1
		group by t1.[ShopId], t1.Date, t1.PersonId, t1.NumberId
		) z1
	group by z1.[ShopId], z1.Date, z1.PersonId
	) d2
on d2.Shopid=d1.Shopid and d2.PersonId=d1.PersonId and d2.Date=d1.Date
left join [BackStore].[dbo].[EntShops] ES on ES.Shopid=d1.shopid
--group by d1.ShopId, d1.Month
Order by d1.Month, d1.Shopid




