--====== Запускать на DL580G2 в базе BaseOrders
select top 10 * from spsssql.Forecast.dbo.Task 
--where TaskTypeId=1
order by TaskId desc


declare @Task int =  --(select top 1 TaskId from spsssql.Forecast.dbo.Task where TaskTypeId=1 order by TaskId desc)
declare @OrderDate date =  convert(date,getdate()) --'2015.03.02'

/******************************/
/*250*/
select ForecastingTask.*
into #ForecastingTask1
from SPSSSQL.FORECAST.dbo.ForecastingTask
join 
(
	select ShopId,ItemId,FrameworkId,ContractorId,OrderDate,max(ResultDateTime) as LastDateTime
	from SPSSSQL.FORECAST.dbo.ForecastingTask 
	where TaskStatusId=2  
				and ShopId=250  --?
				and OrderDate=@OrderDate
				and TaskId=@Task--?
	group by ShopId,ItemId,FrameworkId,ContractorId,OrderDate
) lastData on lastData.ShopId=ForecastingTask.ShopId
					and lastData.ItemId=ForecastingTask.ItemId
					and lastData.FrameworkId=ForecastingTask.FrameworkId
					and lastData.ContractorId=ForecastingTask.ContractorId
					and lastData.OrderDate=ForecastingTask.OrderDate
					and lastData.LastDateTime=ForecastingTask.ResultDateTime
				

--select * from Order_ForecastingTask where ShopId=250 and TaskId=@Task--Task + Shop д.б. пусто
delete from Order_ForecastingTask where ShopId=250 and TaskId=@Task

INSERT INTO [dbo].[Order_ForecastingTask]
(
			[ShopId]
           ,[ItemId]
           ,[TaskId]
           ,[ContractorId]
           ,[FrameWorkId]
           ,[RecommendedOrder]
           ,[TotalConfirmedAmountOfOrder]
           ,[RecommendedRest]
           ,[SafetyStock]
           ,[DemandABSameDays]
           ,[DemandABLastYear]
           ,[ExtraPercent]
           ,[LastError]
           ,[FrcABwEffects]
           ,[Cost]
           ,Signal
           ,CurrentRest
)				
select   #ForecastingTask1.[ShopId]
           ,#ForecastingTask1.[ItemId]
           ,#ForecastingTask1.[TaskId]
           ,#ForecastingTask1.[ContractorId]
           ,#ForecastingTask1.[FrameWorkId]
           ,#ForecastingTask1.[RecommendedOrder]
           ,#ForecastingTask1.[TotalConfirmedAmountOfOrder]
           ,#ForecastingTask1.[RecommendedRest]
           ,#ForecastingTask1.[SafetyStock]
           ,#ForecastingTask1.[DemandABSameDays]
           ,#ForecastingTask1.[DemandABLastYear]
           ,#ForecastingTask1.[ExtraPercent]
           ,#ForecastingTask1.[LastError]
           ,#ForecastingTask1.[FrcABwEffects]
           ,#ForecastingTask1.[Cost]
           ,#ForecastingTask1.Signal
           ,IsNull(#ForecastingTask1.CurrrentRest,0) as CurrrentRest
from #ForecastingTask1
left join dbo.Order_ForecastingTask  (nolock)
					on Order_ForecastingTask.ShopId=#ForecastingTask1.ShopId
					and Order_ForecastingTask.ItemId=#ForecastingTask1.ItemId
					and Order_ForecastingTask.FrameworkId=#ForecastingTask1.FrameworkId
					and Order_ForecastingTask.ContractorId=#ForecastingTask1.ContractorId
					and Order_ForecastingTask.TaskId=#ForecastingTask1.TaskId
where 		Order_ForecastingTask.ItemId is null
					

--declare @counter int
--select @counter =COUNT(*) from #ForecastingTask1 where itemid=21684
--raiserror('%i',18,18,@counter)


update OrdersItems
set AutoQty=IsNull(F.RecommendedOrder,0),TaskId=F.TaskId,AutoQtyComment='Рекомендовано SPSS', 
OrderedQty=IsNull(F.RecommendedOrder,0), ShopOrderedQty=IsNull(F.RecommendedOrder,0)
--select *
from Orders H join OrdersItems D on D.OrderId=H.OrderId
join #ForecastingTask1 F on F.ItemId=D.ItemId and F.ContractorId=H.ContractorId
where H.ShopId=250 and H.OrderDate=@OrderDate --Shop + Date

drop table #ForecastingTask1



/******************************/
/*116*/
select ForecastingTask.*
into #ForecastingTask2
from SPSSSQL.FORECAST.dbo.ForecastingTask
join 
(
	select ShopId,ItemId,FrameworkId,ContractorId,OrderDate,max(ResultDateTime) as LastDateTime
	from SPSSSQL.FORECAST.dbo.ForecastingTask 
	where TaskStatusId=2  
				and ShopId=116  --?
				and OrderDate=@OrderDate --?
				and TaskId=@Task
	group by ShopId,ItemId,FrameworkId,ContractorId,OrderDate
) lastData on lastData.ShopId=ForecastingTask.ShopId
					and lastData.ItemId=ForecastingTask.ItemId
					and lastData.FrameworkId=ForecastingTask.FrameworkId
					and lastData.ContractorId=ForecastingTask.ContractorId
					and lastData.OrderDate=ForecastingTask.OrderDate
					and lastData.LastDateTime=ForecastingTask.ResultDateTime
				

--select * from Order_ForecastingTask where ShopId=116 and TaskId=@Task--Task + Shop д.б. пусто
delete from Order_ForecastingTask where ShopId=116 and TaskId=@Task

INSERT INTO [dbo].[Order_ForecastingTask]
(
			[ShopId]
           ,[ItemId]
           ,[TaskId]
           ,[ContractorId]
           ,[FrameWorkId]
           ,[RecommendedOrder]
           ,[TotalConfirmedAmountOfOrder]
           ,[RecommendedRest]
           ,[SafetyStock]
           ,[DemandABSameDays]
           ,[DemandABLastYear]
           ,[ExtraPercent]
           ,[LastError]
           ,[FrcABwEffects]
           ,[Cost]
           ,Signal
           ,CurrentRest
)				
select   #ForecastingTask2.[ShopId]
           ,#ForecastingTask2.[ItemId]
           ,#ForecastingTask2.[TaskId]
           ,#ForecastingTask2.[ContractorId]
           ,#ForecastingTask2.[FrameWorkId]
           ,#ForecastingTask2.[RecommendedOrder]
           ,#ForecastingTask2.[TotalConfirmedAmountOfOrder]
           ,#ForecastingTask2.[RecommendedRest]
           ,#ForecastingTask2.[SafetyStock]
           ,#ForecastingTask2.[DemandABSameDays]
           ,#ForecastingTask2.[DemandABLastYear]
           ,#ForecastingTask2.[ExtraPercent]
           ,#ForecastingTask2.[LastError]
           ,#ForecastingTask2.[FrcABwEffects]
           ,#ForecastingTask2.[Cost]
           ,#ForecastingTask2.Signal
           ,IsNull(#ForecastingTask2.CurrrentRest,0) as CurrrentRest
from #ForecastingTask2
left join dbo.Order_ForecastingTask  (nolock)
					on Order_ForecastingTask.ShopId=#ForecastingTask2.ShopId
					and Order_ForecastingTask.ItemId=#ForecastingTask2.ItemId
					and Order_ForecastingTask.FrameworkId=#ForecastingTask2.FrameworkId
					and Order_ForecastingTask.ContractorId=#ForecastingTask2.ContractorId
					and Order_ForecastingTask.TaskId=#ForecastingTask2.TaskId
where 		Order_ForecastingTask.ItemId is null
					

--declare @counter int
--select @counter =COUNT(*) from #ForecastingTask2 where itemid=21684
--raiserror('%i',18,18,@counter)


update OrdersItems
set AutoQty=IsNull(F.RecommendedOrder,0),TaskId=F.TaskId,AutoQtyComment='Рекомендовано SPSS', 
OrderedQty=IsNull(F.RecommendedOrder,0), ShopOrderedQty=IsNull(F.RecommendedOrder,0)
--select *
from Orders H join OrdersItems D on D.OrderId=H.OrderId
join #ForecastingTask2 F on F.ItemId=D.ItemId and F.ContractorId=H.ContractorId
where H.ShopId=116 and H.OrderDate=@OrderDate --Shop + Date

drop table #ForecastingTask2



/******************************/
/*27*/
select ForecastingTask.*
into #ForecastingTask3
from SPSSSQL.FORECAST.dbo.ForecastingTask
join 
(
	select ShopId,ItemId,FrameworkId,ContractorId,OrderDate,max(ResultDateTime) as LastDateTime
	from SPSSSQL.FORECAST.dbo.ForecastingTask 
	where TaskStatusId=2  
				and ShopId=27  --?
				and OrderDate=@OrderDate --?
				and TaskId=@Task
	group by ShopId,ItemId,FrameworkId,ContractorId,OrderDate
) lastData on lastData.ShopId=ForecastingTask.ShopId
					and lastData.ItemId=ForecastingTask.ItemId
					and lastData.FrameworkId=ForecastingTask.FrameworkId
					and lastData.ContractorId=ForecastingTask.ContractorId
					and lastData.OrderDate=ForecastingTask.OrderDate
					and lastData.LastDateTime=ForecastingTask.ResultDateTime
				
--д.б. пусто
--select * from Order_ForecastingTask where ShopId=27 and TaskId=@Task--Task + Shop 
delete from Order_ForecastingTask where ShopId=27 and TaskId=@Task

INSERT INTO [dbo].[Order_ForecastingTask]
(
			[ShopId]
           ,[ItemId]
           ,[TaskId]
           ,[ContractorId]
           ,[FrameWorkId]
           ,[RecommendedOrder]
           ,[TotalConfirmedAmountOfOrder]
           ,[RecommendedRest]
           ,[SafetyStock]
           ,[DemandABSameDays]
           ,[DemandABLastYear]
           ,[ExtraPercent]
           ,[LastError]
           ,[FrcABwEffects]
           ,[Cost]
           ,Signal
           ,CurrentRest
)				
select   #ForecastingTask3.[ShopId]
           ,#ForecastingTask3.[ItemId]
           ,#ForecastingTask3.[TaskId]
           ,#ForecastingTask3.[ContractorId]
           ,#ForecastingTask3.[FrameWorkId]
           ,#ForecastingTask3.[RecommendedOrder]
           ,#ForecastingTask3.[TotalConfirmedAmountOfOrder]
           ,#ForecastingTask3.[RecommendedRest]
           ,#ForecastingTask3.[SafetyStock]
           ,#ForecastingTask3.[DemandABSameDays]
           ,#ForecastingTask3.[DemandABLastYear]
           ,#ForecastingTask3.[ExtraPercent]
           ,#ForecastingTask3.[LastError]
           ,#ForecastingTask3.[FrcABwEffects]
           ,#ForecastingTask3.[Cost]
           ,#ForecastingTask3.Signal
           ,IsNull(#ForecastingTask3.CurrrentRest,0) as CurrrentRest
from #ForecastingTask3
left join dbo.Order_ForecastingTask  (nolock)
					on Order_ForecastingTask.ShopId=#ForecastingTask3.ShopId
					and Order_ForecastingTask.ItemId=#ForecastingTask3.ItemId
					and Order_ForecastingTask.FrameworkId=#ForecastingTask3.FrameworkId
					and Order_ForecastingTask.ContractorId=#ForecastingTask3.ContractorId
					and Order_ForecastingTask.TaskId=#ForecastingTask3.TaskId
where 		Order_ForecastingTask.ItemId is null
					

--declare @counter int
--select @counter =COUNT(*) from #ForecastingTask3 where itemid=21684
--raiserror('%i',18,18,@counter)


update OrdersItems
set AutoQty=IsNull(F.RecommendedOrder,0),TaskId=F.TaskId,AutoQtyComment='Рекомендовано SPSS', 
OrderedQty=IsNull(F.RecommendedOrder,0), ShopOrderedQty=IsNull(F.RecommendedOrder,0)
--select *
from Orders H join OrdersItems D on D.OrderId=H.OrderId
join #ForecastingTask3 F on F.ItemId=D.ItemId and F.ContractorId=H.ContractorId
where H.ShopId=27 and H.OrderDate=@OrderDate --Shop + Date

drop table #ForecastingTask3



/******************************/
/*248*/
select ForecastingTask.*
into #ForecastingTask4
from SPSSSQL.FORECAST.dbo.ForecastingTask
join 
(
	select ShopId,ItemId,FrameworkId,ContractorId,OrderDate,max(ResultDateTime) as LastDateTime
	from SPSSSQL.FORECAST.dbo.ForecastingTask 
	where TaskStatusId=2  
				and ShopId=248  --?
				and OrderDate=@OrderDate --?
				and TaskId=@Task
	group by ShopId,ItemId,FrameworkId,ContractorId,OrderDate
) lastData on lastData.ShopId=ForecastingTask.ShopId
					and lastData.ItemId=ForecastingTask.ItemId
					and lastData.FrameworkId=ForecastingTask.FrameworkId
					and lastData.ContractorId=ForecastingTask.ContractorId
					and lastData.OrderDate=ForecastingTask.OrderDate
					and lastData.LastDateTime=ForecastingTask.ResultDateTime
				

--д.б. пусто
--select * from Order_ForecastingTask where ShopId=248 and TaskId=@Task--Task + Shop 
delete from Order_ForecastingTask where ShopId=248 and TaskId=@Task

INSERT INTO [dbo].[Order_ForecastingTask]
(
			[ShopId]
           ,[ItemId]
           ,[TaskId]
           ,[ContractorId]
           ,[FrameWorkId]
           ,[RecommendedOrder]
           ,[TotalConfirmedAmountOfOrder]
           ,[RecommendedRest]
           ,[SafetyStock]
           ,[DemandABSameDays]
           ,[DemandABLastYear]
           ,[ExtraPercent]
           ,[LastError]
           ,[FrcABwEffects]
           ,[Cost]
           ,Signal
           ,CurrentRest
)				
select   #ForecastingTask4.[ShopId]
           ,#ForecastingTask4.[ItemId]
           ,#ForecastingTask4.[TaskId]
           ,#ForecastingTask4.[ContractorId]
           ,#ForecastingTask4.[FrameWorkId]
           ,#ForecastingTask4.[RecommendedOrder]
           ,#ForecastingTask4.[TotalConfirmedAmountOfOrder]
           ,#ForecastingTask4.[RecommendedRest]
           ,#ForecastingTask4.[SafetyStock]
           ,#ForecastingTask4.[DemandABSameDays]
           ,#ForecastingTask4.[DemandABLastYear]
           ,#ForecastingTask4.[ExtraPercent]
           ,#ForecastingTask4.[LastError]
           ,#ForecastingTask4.[FrcABwEffects]
           ,#ForecastingTask4.[Cost]
           ,#ForecastingTask4.Signal
           ,IsNull(#ForecastingTask4.CurrrentRest,0) as CurrrentRest
from #ForecastingTask4
left join dbo.Order_ForecastingTask  (nolock)
					on Order_ForecastingTask.ShopId=#ForecastingTask4.ShopId
					and Order_ForecastingTask.ItemId=#ForecastingTask4.ItemId
					and Order_ForecastingTask.FrameworkId=#ForecastingTask4.FrameworkId
					and Order_ForecastingTask.ContractorId=#ForecastingTask4.ContractorId
					and Order_ForecastingTask.TaskId=#ForecastingTask4.TaskId
where 		Order_ForecastingTask.ItemId is null
					

--declare @counter int
--select @counter =COUNT(*) from #ForecastingTask4 where itemid=21684
--raiserror('%i',18,18,@counter)


update OrdersItems
set AutoQty=IsNull(F.RecommendedOrder,0),TaskId=F.TaskId,AutoQtyComment='Рекомендовано SPSS', 
OrderedQty=IsNull(F.RecommendedOrder,0), ShopOrderedQty=IsNull(F.RecommendedOrder,0)
--select *
from Orders H join OrdersItems D on D.OrderId=H.OrderId
join #ForecastingTask4 F on F.ItemId=D.ItemId and F.ContractorId=H.ContractorId
where H.ShopId=248 and H.OrderDate=@OrderDate --Shop + Date

drop table #ForecastingTask4



--====== Запускать на DL580G2 в базе BaseOrders
 --Исходник

--select ForecastingTask.*
--into #ForecastingTask
--from SPSSSQL.FORECAST.dbo.ForecastingTask
--join 
--(
--	select ShopId,ItemId,FrameworkId,ContractorId,OrderDate,max(ResultDateTime) as LastDateTime
--	from SPSSSQL.FORECAST.dbo.ForecastingTask 
--	where TaskStatusId=2  
--				and ShopId=250  --?
--				and OrderDate=@OrderDate --?
--	group by ShopId,ItemId,FrameworkId,ContractorId,OrderDate
--) lastData on lastData.ShopId=ForecastingTask.ShopId
--					and lastData.ItemId=ForecastingTask.ItemId
--					and lastData.FrameworkId=ForecastingTask.FrameworkId
--					and lastData.ContractorId=ForecastingTask.ContractorId
--					and lastData.OrderDate=ForecastingTask.OrderDate
--					and lastData.LastDateTime=ForecastingTask.ResultDateTime
				

--select * from Order_ForecastingTask where ShopId=250 and TaskId=@Task--Task + Shop д.б. пусто
----delete from Order_ForecastingTask where ShopId=250 TaskId=@Task

--INSERT INTO [dbo].[Order_ForecastingTask]
--(
--			[ShopId]
--           ,[ItemId]
--           ,[TaskId]
--           ,[ContractorId]
--           ,[FrameWorkId]
--           ,[RecommendedOrder]
--           ,[TotalConfirmedAmountOfOrder]
--           ,[RecommendedRest]
--           ,[SafetyStock]
--           ,[DemandABSameDays]
--           ,[DemandABLastYear]
--           ,[ExtraPercent]
--           ,[LastError]
--           ,[FrcABwEffects]
--           ,[Cost]
--           ,Signal
--           ,CurrentRest
--)				
--select   #ForecastingTask.[ShopId]
--           ,#ForecastingTask.[ItemId]
--           ,#ForecastingTask.[TaskId]
--           ,#ForecastingTask.[ContractorId]
--           ,#ForecastingTask.[FrameWorkId]
--           ,#ForecastingTask.[RecommendedOrder]
--           ,#ForecastingTask.[TotalConfirmedAmountOfOrder]
--           ,#ForecastingTask.[RecommendedRest]
--           ,#ForecastingTask.[SafetyStock]
--           ,#ForecastingTask.[DemandABSameDays]
--           ,#ForecastingTask.[DemandABLastYear]
--           ,#ForecastingTask.[ExtraPercent]
--           ,#ForecastingTask.[LastError]
--           ,#ForecastingTask.[FrcABwEffects]
--           ,#ForecastingTask.[Cost]
--           ,#ForecastingTask.Signal
--           ,IsNull(#ForecastingTask.CurrrentRest,0) as CurrrentRest
--from #ForecastingTask
--left join dbo.Order_ForecastingTask  (nolock)
--					on Order_ForecastingTask.ShopId=#ForecastingTask.ShopId
--					and Order_ForecastingTask.ItemId=#ForecastingTask.ItemId
--					and Order_ForecastingTask.FrameworkId=#ForecastingTask.FrameworkId
--					and Order_ForecastingTask.ContractorId=#ForecastingTask.ContractorId
--					and Order_ForecastingTask.TaskId=#ForecastingTask.TaskId
--where 		Order_ForecastingTask.ItemId is null
					

----declare @counter int
----select @counter =COUNT(*) from #ForecastingTask where itemid=21684
----raiserror('%i',18,18,@counter)


--update OrdersItems
--set AutoQty=IsNull(F.RecommendedOrder,0),TaskId=F.TaskId,AutoQtyComment='Рекомендовано SPSS', 
--OrderedQty=IsNull(F.RecommendedOrder,0), ShopOrderedQty=IsNull(F.RecommendedOrder,0)
----select *
--from Orders H join OrdersItems D on D.OrderId=H.OrderId
--join #ForecastingTask F on F.ItemId=D.ItemId and F.ContractorId=H.ContractorId
--where H.ShopId=250 and H.OrderDate=@OrderDate --Shop + Date

--drop table #ForecastingTask


--select  TaskId, AutoQtyComment, AutoQty, OrderedQty, ShopOrderedQty, * 
--from Orders H join OrdersItems D on D.OrderId=H.OrderId where H.ShopId=250 and H.OrderDate=@OrderDate --and TaskId=221

--select  TaskId, AutoQtyComment, AutoQty, OrderedQty, ShopOrderedQty, * 
--from Orders H join OrdersItems D on D.OrderId=H.OrderId where H.ShopId=250 and H.OrderDate=@OrderDate and OrderStatusId<>-1 --Немакеты

--select  TaskId, AutoQtyComment, AutoQty, OrderedQty, ShopOrderedQty, * 
--from Orders H join OrdersItems D on D.OrderId=H.OrderId where H.ShopId=250 and H.OrderDate=@OrderDate and (AutoQty<>0 or OrderedQty<>0 or ShopOrderedQty<>0)


/*
update oi 
set oi.AutoQty=IsNull(#ForecastingTask.RecommendedOrder,0),TaskId=#ForecastingTask.TaskId,AutoQtyComment='Рекомендовано SPSS'
from @OrdersItems oi
join #ForecastingTask on #ForecastingTask.ItemId=oi.ItemId and #ForecastingTask.ContractorId=@ContractorId

update oi 
set oi.AutoQty=0,AutoQtyComment='Нет рекомендаций'
from @OrdersItems oi
left join #ForecastingTask on #ForecastingTask.ItemId=oi.ItemId and #ForecastingTask.ContractorId=@ContractorId
where  #ForecastingTask.ItemId is null
*/