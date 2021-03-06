USE [FrontStore]
GO
/****** Object:  StoredProcedure [dbo].[KassirForecast]    Script Date: 07/14/2015 10:04:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[KassirForecast] 
(
	@CurrentWeek date = null,
	@K decimal = null
)
AS
set nocount on
BEGIN


if @CurrentWeek is null Set @CurrentWeek = convert(date,getdate())
declare @NextWeek date = dateadd(d,7,@CurrentWeek)
declare @PreviousWeek date = dateadd(d,-7,@CurrentWeek)
set datefirst 1

IF OBJECT_ID('tempdb..#Shops') IS NOT NULL BEGIN DROP TABLE #Shops Print 'Deleted #Shops' END	
select Shopid,ShopName,[ParentShopTypeID] ,[ParentShopTypeName], (case when ParentShopTypeID!=103 then 1 else 0 end) as SM
into #Shops
from Backstore.dbo.EntShops
where TradeArea is not null
	and [Active]=1
	and [SQLServer] is not null


/*Установка коэффициентов*/
--Время на операции сканирования одной SKU, сек
declare @SMcoef decimal(8,3) = 3.5
declare @GMcoef decimal(8,3) = 4

--Время на нерассчитываемые операции на один чек (открытие + закрытие), сек
declare @SMbill decimal(8,3) = 25
declare @GMbill decimal(8,3) = 30

--К-т использования времен
if @K is null Set @K = 0.7


/*Супера + Гипера*/
--1.1. Продажи на прошлой неделе
IF OBJECT_ID('tempdb..#tab1') IS NOT NULL BEGIN DROP TABLE #tab1 Print 'Deleted #tab1' END	
select 
BillShifts.ShopId
,convert(date,BillShifts.DateOpen) as Day
,DATEPART(dw,BillShifts.DateOpen) as WeekNum
,datepart(hour,BillHeaders.DateOpen) as Hour
,count(distinct BillShifts.LogicalNumber) as Casses
,count(distinct BillHeaders.PersonId) as Persons
,count(*)	as BillCount
,sum(lines) as Positions
,(sum(lines)*(case when #Shops.SM=1 then @SMcoef else @GMcoef end) + (case when #Shops.SM=1 then @SMbill else @GMbill end) * count(*) ) PositionsTime
,(sum(lines)*(case when #Shops.SM=1 then @SMcoef else @GMcoef end) + (case when #Shops.SM=1 then @SMbill else @GMbill end) * count(*) )/cast(60*60*@K as decimal(18,9)) as N
into #tab1
from dbo.BillShifts (nolock)
join dbo.BillHeaders (nolock) on BillShifts.Shiftid=BillHeaders.Shiftid
join #Shops on #Shops.ShopID=BillShifts.ShopId --and #Shops.SM=1
where DATEPART(wk, @PreviousWeek) = DATEPART(wk, BillShifts.DateOpen)
		and DATEPART(year, @PreviousWeek) = DATEPART(year, BillShifts.DateOpen)
		--and BillShifts.ShopId=16
group by datepart(hour,BillHeaders.DateOpen), DATEPART(dw,BillShifts.DateOpen)
,convert(date,BillShifts.DateOpen),BillShifts.ShopId, #Shops.SM
order by DATEPART(dw,BillShifts.DateOpen), datepart(hour,BillHeaders.DateOpen)

--1.2. Расчет распределения продаж по часам в каждый день недели.
IF OBJECT_ID('tempdb..#SM_CurrYearPrevWeek') IS NOT NULL BEGIN DROP TABLE #SM_CurrYearPrevWeek Print 'Deleted #SM_CurrYearPrevWeek' END	
select z.shopid, Hour,z.WeekNum, Z.Day, H.IsHolidayDay, H.IsNonworkingDay, H.HolidayTypeId
,Casses,Persons,BillCount
,(case when q.BillCountSum = 0 then null else z.BillCount*1.0/q.BillCountSum  end) as Ratio
,(case when p.BillCountSumWeek = 0 then null else q.BillCountSum*1.0/p.BillCountSumWeek end) as RatioWeek
,Positions
,isnull(N,1) as RawN
,N-N%1+case when N%1>0.1  or N<=0.1 then 1 else 0 end as N
,(case when N=0 then null else PositionsTime/(N-N%1+case when N%1>0.1 or N<=0.1 then 1 else 0 end) end) as FullTime
,(case when N=0 then null else 3600-PositionsTime/(N-N%1+case when N%1>0.1 or N<=0.1 then 1 else 0 end) end) as OutTime
,1 as Today
into #SM_CurrYearPrevWeek
from #tab1 z
left join 
(
	select shopid, weeknum,sum(BillCount) as BillCountSum
	from #tab1 z
	group by shopid,weeknum
) q on q.WeekNum=z.WeekNum and q.shopid=z.ShopId
left join 
(
	select shopid, sum(BillCount) as BillCountSumWeek
	from #tab1 z group by shopid
) p on z.WeekNum>0 and p.shopid=z.ShopId
left join [BackStore].[dbo].[Holidays] H on H.Date=Z.Day
order by z.shopid, WeekNum,Hour



--2.1. Продажи на этой неделе (чисто для проверки прогнозов, в расчете не участвует)
IF OBJECT_ID('tempdb..#tab4') IS NOT NULL BEGIN DROP TABLE #tab4 Print 'Deleted #tab4' END	
select 
BillShifts.ShopId
,convert(date,BillShifts.DateOpen) as Day
,DATEPART(dw,BillShifts.DateOpen) as WeekNum
,datepart(hour,BillHeaders.DateOpen) as Hour
,count(distinct BillShifts.LogicalNumber) as Casses
,count(distinct BillHeaders.PersonId) as Persons
,count(*)	as BillCount
,sum(lines) as Positions
,(sum(lines)*(case when #Shops.SM=1 then @SMcoef else @GMcoef end) + (case when #Shops.SM=1 then @SMbill else @GMbill end) * count(*) ) PositionsTime
,(sum(lines)*(case when #Shops.SM=1 then @SMcoef else @GMcoef end) + (case when #Shops.SM=1 then @SMbill else @GMbill end) * count(*) )/cast(60*60*@K as decimal(18,9)) as N
into #tab4
from dbo.BillShifts (nolock)
join dbo.BillHeaders (nolock) on BillShifts.Shiftid=BillHeaders.Shiftid
join #Shops on #Shops.ShopID=BillShifts.ShopId --and #Shops.SM=1
where DATEPART(wk, @CurrentWeek) = DATEPART(wk, BillShifts.DateOpen)
		and DATEPART(year, @CurrentWeek) = DATEPART(year, BillShifts.DateOpen)
		--and BillShifts.ShopId=16
group by datepart(hour,BillHeaders.DateOpen), DATEPART(dw,BillShifts.DateOpen)
,convert(date,BillShifts.DateOpen), BillShifts.ShopId, #Shops.SM
order by DATEPART(dw,BillShifts.DateOpen), datepart(hour,BillHeaders.DateOpen)


--2.2. Расчет распределения продаж по часам в каждый день недели.
IF OBJECT_ID('tempdb..#SM_CurrYearCurrWeek') IS NOT NULL BEGIN DROP TABLE #SM_CurrYearCurrWeek Print 'Deleted #SM_CurrYearCurrWeek' END	
select z.ShopId, Hour,z.WeekNum,Casses,Persons,BillCount, Z.Day, H.IsHolidayDay, H.IsNonworkingDay, H.HolidayTypeId
,(case when q.BillCountSum = 0 then null else z.BillCount*1.0/q.BillCountSum  end) as Ratio
,(case when p.BillCountSumWeek = 0 then null else q.BillCountSum*1.0/p.BillCountSumWeek end) as RatioWeek
,Positions
,isnull(N,1) as RawN
,N-N%1+case when N%1>0.1  or N<=0.1 then 1 else 0 end as N
,(case when N=0 then null else PositionsTime/(N-N%1+case when N%1>0.1 or N<=0.1 then 1 else 0 end) end) as FullTime
,(case when N=0 then null else 3600-PositionsTime/(N-N%1+case when N%1>0.1 or N<=0.1 then 1 else 0 end) end) as OutTime
,1 as Today
into #SM_CurrYearCurrWeek
from #tab4 z
left join 
(
	select shopid, weeknum,sum(BillCount) as BillCountSum
	from #tab4 z
	group by shopid, weeknum
) q
on q.WeekNum=z.WeekNum and q.shopid=z.ShopId
left join 
(
	select shopid, sum(BillCount) as BillCountSumWeek
	from #tab1 z group by shopid
) p on z.WeekNum>0 and p.shopid=z.ShopId
left join [BackStore].[dbo].[Holidays] H on H.Date=Z.Day
order by WeekNum,Hour




--3.1. Год назад - прошлая неделя
IF OBJECT_ID('tempdb..#tab2') IS NOT NULL BEGIN DROP TABLE #tab2 Print 'Deleted #tab2' END	
select 
BillShifts.ShopId
,convert(date,BillShifts.DateOpen) as Day
,DATEPART(dw,BillShifts.DateOpen) as WeekNum
,datepart(hour,BillHeaders.DateOpen) as Hour
,count(distinct BillShifts.LogicalNumber) as Casses
,count(distinct BillHeaders.PersonId) as Persons
,count(*)	as BillCount
,sum(lines) as Positions
,(sum(lines)*(case when #Shops.SM=1 then @SMcoef else @GMcoef end) + (case when #Shops.SM=1 then @SMbill else @GMbill end) * count(*) ) PositionsTime
,(sum(lines)*(case when #Shops.SM=1 then @SMcoef else @GMcoef end) + (case when #Shops.SM=1 then @SMbill else @GMbill end) * count(*) )/cast(60*60*@K as decimal(18,9)) as N
into #tab2
from dbo.BillShifts (nolock)
join dbo.BillHeaders (nolock) on BillShifts.Shiftid=BillHeaders.Shiftid
join #Shops on #Shops.ShopID=BillShifts.ShopId --and #Shops.SM=1
where   DATEPART(wk, BillShifts.DateOpen) = DATEPART(wk, @PreviousWeek)
		and DATEPART(year, BillShifts.DateOpen)=DATEPART(year, dateadd(year,-1,@PreviousWeek))
		--and BillShifts.ShopId=16
group by datepart(hour,BillHeaders.DateOpen), DATEPART(dw,BillShifts.DateOpen)
,convert(date,BillShifts.DateOpen), BillShifts.ShopId, #Shops.SM
order by DATEPART(dw,BillShifts.DateOpen), datepart(hour,BillHeaders.DateOpen)


--3.2. Расчет распределения продаж по часам в каждый день недели.
IF OBJECT_ID('tempdb..#Super_YearAgo_PrevWeek') IS NOT NULL BEGIN DROP TABLE #Super_YearAgo_PrevWeek Print 'Deleted #Super_YearAgo_PrevWeek' END	
select z.shopid, Hour,z.WeekNum,Casses,Persons,BillCount, Z.Day, H.IsHolidayDay, H.IsNonworkingDay, H.HolidayTypeId
,(case when q.BillCountSum = 0 then null else z.BillCount*1.0/q.BillCountSum  end) as Ratio
,(case when p.BillCountSumWeek = 0 then null else q.BillCountSum*1.0/p.BillCountSumWeek end) as RatioWeek
,Positions
,isnull(N,1) as RawN
,N-N%1+case when N%1>0.1  or N<=0.1 then 1 else 0 end as N
,(case when N=0 then null else PositionsTime/(N-N%1+case when N%1>0.1 or N<=0.1 then 1 else 0 end) end) as FullTime
,(case when N=0 then null else 3600-PositionsTime/(N-N%1+case when N%1>0.1 or N<=0.1 then 1 else 0 end) end) as OutTime
,0 as Today
into #Super_YearAgo_PrevWeek
from #tab2 z
left join 
(
	select shopid,weeknum,sum(BillCount) as BillCountSum
	from #tab2 z
	group by shopid,weeknum
) q on q.WeekNum=z.WeekNum and q.shopid=z.shopid
left join 
(
	select shopid,sum(BillCount) as BillCountSumWeek
	from #tab2 z group by shopid
) p on z.WeekNum>0 and p.shopid=z.shopid
left join [BackStore].[dbo].[Holidays] H on H.Date=Z.Day
order by WeekNum,Hour




--4.1. Год назад - следуюшая неделя
IF OBJECT_ID('tempdb..#tab3') IS NOT NULL BEGIN DROP TABLE #tab3 Print 'Deleted #tab3' END	
select 
BillShifts.ShopId
,convert(date,BillShifts.DateOpen) as Day
,DATEPART(dw,BillShifts.DateOpen) as WeekNum
,datepart(hour,BillHeaders.DateOpen) as Hour
,count(distinct BillShifts.LogicalNumber) as Casses
,count(distinct BillHeaders.PersonId) as Persons
,count(*)	as BillCount
,sum(lines) as Positions
,(sum(lines)*(case when #Shops.SM=1 then @SMcoef else @GMcoef end) + (case when #Shops.SM=1 then @SMbill else @GMbill end) * count(*) ) PositionsTime
,(sum(lines)*(case when #Shops.SM=1 then @SMcoef else @GMcoef end) + (case when #Shops.SM=1 then @SMbill else @GMbill end) * count(*) )/cast(60*60*@K as decimal(18,9)) as N
into #tab3
from dbo.BillShifts (nolock)
join dbo.BillHeaders (nolock) on BillShifts.Shiftid=BillHeaders.Shiftid
join #Shops on #Shops.ShopID=BillShifts.ShopId --and #Shops.SM=1
where   DATEPART(wk, BillShifts.DateOpen) = DATEPART(wk, @NextWeek)
		and DATEPART(year, BillShifts.DateOpen)=DATEPART(year, dateadd(year,-1,@NextWeek))
		--and BillShifts.ShopId=16
group by datepart(hour,BillHeaders.DateOpen), DATEPART(dw,BillShifts.DateOpen)
,convert(date,BillShifts.DateOpen), BillShifts.ShopId, #Shops.SM
order by DATEPART(dw,BillShifts.DateOpen), datepart(hour,BillHeaders.DateOpen)


--4.2. асчет распределения продаж по часам в каждый день недели.
IF OBJECT_ID('tempdb..#Super_YearAgo_NextWeek') IS NOT NULL BEGIN DROP TABLE #Super_YearAgo_NextWeek Print 'Deleted #Super_YearAgo_NextWeek' END	
select z.ShopId, Hour,z.WeekNum,Casses,Persons,BillCount, Z.Day, H.IsHolidayDay, H.IsNonworkingDay, H.HolidayTypeId
,(case when q.BillCountSum = 0 then null else z.BillCount*1.0/q.BillCountSum  end) as Ratio
,(case when p.BillCountSumWeek = 0 then null else q.BillCountSum*1.0/p.BillCountSumWeek end) as RatioWeek
,Positions
,isnull(N,1) as RawN
,N-N%1+case when N%1>0.1  or N<=0.1 then 1 else 0 end as N
,(case when N=0 then null else PositionsTime/(N-N%1+case when N%1>0.1 or N<=0.1 then 1 else 0 end) end) as FullTime
,(case when N=0 then null else 3600-PositionsTime/(N-N%1+case when N%1>0.1 or N<=0.1 then 1 else 0 end) end) as OutTime
,0 as Today
into #Super_YearAgo_NextWeek
from #tab3 z
left join 
(
	select ShopId, weeknum,sum(BillCount) as BillCountSum
	from #tab3 z
	group by ShopId, weeknum
) q on q.WeekNum=z.WeekNum and q.ShopId=z.ShopId
left join 
(
	select ShopId, sum(BillCount) as BillCountSumWeek
	from #tab3 z group by ShopId
) p on z.WeekNum>0 and p.ShopId=z.ShopId
left join [BackStore].[dbo].[Holidays] H on H.Date=Z.Day
order by WeekNum,Hour



--5. К-т праздников. Год назад, поиск по трем неделям: эта, следующая, предыдущая
IF OBJECT_ID('tempdb..#HolidayZ') IS NOT NULL BEGIN DROP TABLE #HolidayZ Print 'Deleted #HolidayZ' END	
select BillShifts.ShopId
, #Shops.SM
,convert(date,BillShifts.DateOpen) as Day
,DATEPART(dw,BillShifts.DateOpen) as WeekNum
,datepart(hour,BillHeaders.DateOpen) as Hour
, H.HolidayTypeId
, H.IsHolidayDay
, H.IsNonworkingDay
,count(*)	as BillCount
into #HolidayZ
from dbo.BillShifts (nolock)
join dbo.BillHeaders (nolock) on BillShifts.Shiftid=BillHeaders.Shiftid
join #Shops on #Shops.ShopID=BillShifts.ShopId --and #Shops.SM=1
left join [BackStore].[dbo].[Holidays] H on H.Date=convert(date,BillShifts.DateOpen)
where ( DATEPART(wk, BillShifts.DateOpen) = DATEPART(wk, @PreviousWeek)
		or DATEPART(wk, BillShifts.DateOpen) = DATEPART(wk, dateadd(d,7,@PreviousWeek))
		or DATEPART(wk, BillShifts.DateOpen) = DATEPART(wk, dateadd(d,-7,@PreviousWeek))
	   )
		and DATEPART(year, BillShifts.DateOpen)=DATEPART(year, dateadd(year,-1,@PreviousWeek))
		--and BillShifts.ShopId=16
group by BillShifts.ShopId, #Shops.SM, convert(date,BillShifts.DateOpen) 
,DATEPART(dw,BillShifts.DateOpen), datepart(hour,BillHeaders.DateOpen)
, H.HolidayTypeId, H.IsHolidayDay, H.IsNonworkingDay
order by DATEPART(dw,BillShifts.DateOpen), datepart(hour,BillHeaders.DateOpen)

--Сам к-т для магазина
IF OBJECT_ID('tempdb..#HolydayCoef') IS NOT NULL BEGIN DROP TABLE #HolydayCoef Print 'Deleted #HolydayCoef' END	
select shopid
,sum(BillCountNonHoliday) *1.0/SUM(case when IsHolidayDay=0 then 1 else 0 end) as AvgBillNonHoliday --Делим кол-во чеков на кол-во дней НЕ праздников за весь период = ср. кол-во чеок вне праздников
,SUM(BillCountHoliday) *1.0/SUM(case when IsHolidayDay=1 then 1 else 0 end) as AvgBillHoliday --ср кол-во чеков в день праздника
,isnull(( SUM(BillCountHoliday) *1.0/SUM(case when IsHolidayDay=1 then 1 else 0 end) ) / ( sum(BillCountNonHoliday) *1.0/SUM(case when IsHolidayDay=0 then 1 else 0 end) ),1) as HolidayCoef
into #HolydayCoef
from
	(select ShopId, Day, WeekNum, IsHolidayDay
	, (case when IsHolidayDay=0 then sum(BillCount) end) as BillCountNonHoliday
	, (case when IsHolidayDay=1 then sum(BillCount) end) as BillCountHoliday
	from #HolidayZ
	group by ShopId, Day, WeekNum, IsHolidayDay
	) t1
group by shopid



/*Выводная таблица*/
--declare @CurrentWeek date = convert(date,getdate())
--declare @NextWeek date = dateadd(d,7,@CurrentWeek)
--declare @PreviousWeek date = dateadd(d,-7,@CurrentWeek)

select t1.Shopid as [Код магазина], #Shops.ShopName as [Магазин]
, convert(date,dateadd(day,-14,DD.Date)) as [Дата базы]
, convert(date,DD.Date) as [Дата прогноза],DD.[DayOfWeekRu] as [День недели]
, t2.Hour as [time]
,(case when t2.Hour=0 then '00:00-00:59'
		when t2.Hour=1 then '01:00-01:59'
		when t2.Hour=2 then '02:00-02:59'
		when t2.Hour=3 then '03:00-03:59'
		when t2.Hour=4 then '04:00-04:59'
		when t2.Hour=5 then '05:00-05:59'
		when t2.Hour=6 then '06:00-06:59'
		when t2.Hour=7 then '07:00-07:59'
		when t2.Hour=8 then '08:00-08:59'
		when t2.Hour=9 then '09:00-09:59'
		when t2.Hour=10 then '10:00-10:59'
		when t2.Hour=11 then '11:00-11:59'
		when t2.Hour=12 then '12:00-12:59'
		when t2.Hour=13 then '13:00-13:59'
		when t2.Hour=14 then '14:00-14:59'
		when t2.Hour=15 then '15:00-15:59'
		when t2.Hour=16 then '16:00-16:59'
		when t2.Hour=17 then '17:00-17:59'
		when t2.Hour=18 then '18:00-18:59'
		when t2.Hour=19 then '19:00-19:59'
		when t2.Hour=20 then '20:00-20:59'
		when t2.Hour=21 then '21:00-21:59'
		when t2.Hour=22 then '22:00-22:59'
		when t2.Hour=23 then '23:00-23:59'
	end) as [Диапазон времени]
--,t2.RawN as RawN_CurrYearPrevWeek										--Оптимальное дробное кол-во кассиров на прошлой неделе
--,convert(int,t2.N) as N_CurrYearPrevWeek_Optimum						--Оптимальное целое кол-во кассиров на прошлой неделе
,t2.Persons as [Кассиров по факту на прошлой неделе]								--Кол-во кассиров на прошлой неделе
,t2.Casses as [Работало касс на прошлой неделе]
,t2.BillCount as [Чеков на прошлой неделе]								--Кол-во чеков на прошлой неделе
,isnull(t3.RatioWeek/t1.RatioWeek * (case when H.IsHolidayDay=1 then HC.HolidayCoef else 1 end),1) as [К-т прогноза]					--К-т с учетом дней недели, но без учета часовой нагрузки. Плюс усчет праздников
--,(t3.Ratio*t3.RatioWeek)/(t1.Ratio*t1.RatioWeek) as [К-т прогноза]		--К-т с учетом дней недели и часовой нагрузки
,convert(int, isnull(( (t2.RawN* isnull(t3.RatioWeek/t1.RatioWeek * (case when H.IsHolidayDay=1 then HC.HolidayCoef else 1 end),1) )
					-(t2.RawN*isnull(t3.RatioWeek/t1.RatioWeek * (case when H.IsHolidayDay=1 then HC.HolidayCoef else 1 end),1) )%1
					+case when (t2.RawN*isnull(t3.RatioWeek/t1.RatioWeek * (case when H.IsHolidayDay=1 then HC.HolidayCoef else 1 end),1))%1>0.1  
								or (t2.RawN*isnull(t3.RatioWeek/t1.RatioWeek * (case when H.IsHolidayDay=1 then HC.HolidayCoef else 1 end),1))<0.1 
					then 1 else 0 end)
				,t2.Persons*isnull(t3.RatioWeek/t1.RatioWeek * (case when H.IsHolidayDay=1 then HC.HolidayCoef else 1 end),1) ))
 as [Прогноз кассиров]													--Прогноз кол-ва кассиров с учетом часовой нагрузки И дней недели
 --Сначала берется оптимальное число кассиров (дробное) и усножается на к-т прогноза. Если этого числа нет (т.е. нет данных прошлой недели), то берется фактическое число кассиров и умножается на к-т

--,convert(int, ( (t2.RawN*(t3.Ratio*t3.RatioWeek)/(t1.Ratio*t1.RatioWeek))
--					-(t2.RawN*(t3.Ratio*t3.RatioWeek)/(t1.Ratio*t1.RatioWeek))%1
--					+case when (t2.RawN*(t3.Ratio*t3.RatioWeek)/(t1.Ratio*t1.RatioWeek))%1>0.1  or (t2.RawN*(t3.Ratio*t3.RatioWeek)/(t1.Ratio*t1.RatioWeek))<0.1 
--					then 1 else 0 end)) 
-- as [Прогноз кассиров]													--Прогноз кол-ва кассиров с учетом часовой нагрузки И дней недели
--,convert(int,(t3.Ratio*t3.RatioWeek)/(t1.Ratio*t1.RatioWeek)*t2.BillCount) 
-- as [BillCount_ForecastCurrentWeek]									--Прогноз кол-ва чеков с учетом часовой нагрузки И дней недели
--,CYCW.BillCount as BillCount_FactCurrentWeek							--кол-во счетов по факту (если берется @CurrentWeek с прошлой недели)
--, (t3.Ratio)/t1.Ratio) as Coef										--К-т с учетом часовой нагрузки но без учета дней недели
--, t1.Ratio/t3.Ratio * t2.RawN as RawN_ft								--Прогноз дробного кол-ва кассиров с учетом часовой нагрузки, но без учета дней недели
--,convert(int, ( (t2.RawN*t1.Ratio/t3.Ratio)-(t2.RawN*t1.Ratio/t3.Ratio)%1 
--	+ case when (t2.RawN*t1.Ratio/t3.Ratio)%1>0.1  or (t2.RawN*t1.Ratio/t3.Ratio)<0.1 
--	then 1 else 0 end)) 
-- as N_ft																--Прогноз целого кол-ва кассиров с учетом часовой нагрузки, но без учета дней недели
--,convert(int,t1.Ratio/t3.Ratio*t2.BillCount) as BillCount_CWft		--Прогноз кол-ва чеков с учетом часовой нагрузки, но без учета дней недели
from #Super_YearAgo_PrevWeek t1
full outer join #SM_CurrYearPrevWeek t2 on t2.WeekNum=t1.WeekNum and t2.Hour=t1.Hour and t2.ShopId=t1.ShopId
full outer join #Super_YearAgo_NextWeek t3 on t3.WeekNum=t1.WeekNum and t3.Hour=t1.Hour and t3.ShopId=t1.ShopId
left join #SM_CurrYearCurrWeek CYCW on CYCW.WeekNum=t1.WeekNum and CYCW.Hour=t1.Hour and CYCW.ShopId=t1.ShopId
left join [BackStore].[dbo].[DateDimension] DD on DATEPART(wk, DD.Date)=DATEPART(wk, @NextWeek) and DATEPART(dw,DD.Date)=t2.WeekNum and DATEPART(year,DD.Date)=DATEPART(year, @NextWeek)
left join [BackStore].[dbo].[Holidays] H on H.Date=convert(date,DD.Date)
left join #HolydayCoef HC on HC.ShopId=t1.ShopId
join #Shops on #Shops.Shopid=t1.ShopId
where t1.ShopId is not null and t2.Hour is not null
order by t1.Shopid,t2.WeekNum, t2.hour


--Исходный код Алексея Алтунина
/*
select Hour,Casses,Persons,BillCount,Positions
,N-N%1+case when N%1>0.1  or N<0.1 then 1 else 0 end as N
,PositionsTime/(N-N%1+case when N%1>0.1 or N<0.1 then 1 else 0 end) as FullTime
,3600-PositionsTime/(N-N%1+case when N%1>0.1 or N<0.1 then 1 else 0 end) as OutTime
from
(
	select 
	datepart(hour,BillHeaders.DateOpen) as Hour
	,count(distinct BillShifts.LogicalNumber) as Casses
	,count(distinct BillHeaders.PersonId) as Persons
	,count(*)	as BillCount
	,sum(lines) as Positions
	,(sum(lines)*3.5+25*count(*)) PositionsTime
	,(sum(lines)*3.5+25*count(*))/cast(60*60*0.7 as decimal(18,9)) as N
	from dbo.BillShifts (nolock)
	join dbo.BillHeaders (nolock) on BillShifts.Shiftid=BillHeaders.Shiftid
	where cast(BillShifts.DateOpen as date) between '2015.04.19' and '2015.04.19'
		  and BillShifts.ShopId=16
	group by datepart(hour,BillHeaders.DateOpen)
) z
order by Hour

select Hour,Casses,Persons,BillCount,Positions,N-N%1+case when N%1>0.1  or N<0.1 then 1 else 0 end,PositionsTime/(N-N%1+case when N%1>0.1 or N<0.1 then 1 else 0 end)
,3600-PositionsTime/(N-N%1+case when N%1>0.1 or N<0.1 then 1 else 0 end)
from
(
	select 
	datepart(hour,BillHeaders.DateOpen) as Hour
	,count(distinct BillShifts.LogicalNumber) as Casses
	,count(distinct BillHeaders.PersonId) as Persons
	,count(*)	as BillCount
	,sum(lines) as Positions
	,(sum(lines)*4+30*count(*)) PositionsTime
	,(sum(lines)*4+30*count(*))/cast(60*60*0.7 as decimal(18,9)) as N
	from dbo.BillShifts (nolock)
	join dbo.BillHeaders (nolock) on BillShifts.Shiftid=BillHeaders.Shiftid
	where cast(BillShifts.DateOpen as date) between '2015.04.19' and '2015.04.19'
		  and BillShifts.ShopId=263
	group by datepart(hour,BillHeaders.DateOpen)
) z
order by Hour
*/



END