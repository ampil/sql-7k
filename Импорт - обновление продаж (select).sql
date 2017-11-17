--- Определение даты обновления
declare @OperReloadDate datetime
set @OperReloadDate = (select min(ReloadDate) from ShopdateReload)

----=============================== Товародвидение =======================
--- Удаление
--delete from dbo.ForecastOperationsPart where Date >= @OperReloadDate

--- Обновление данных
declare @DateBegin datetime, @DateEnd datetime
set @DateBegin = @OperReloadDate
set @DateEnd = DateAdd(Day,-1,convert(varchar(10),GETDATE(),102))

----- Все ПРИХОДНЫЕ операции
--insert into dbo.ForecastOperationsPart (ShopId,Date,ItemId,ForecastOperationTypeId,Qty)
select P.ShopId, P.Date, P.ItemId, 
case 
	--продажи
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (3,204,302) and P.OperationStatusId <> 4 then 2	--возврат с розничных продаж без уценки и необработки
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (3,204,302) and P.OperationStatusId = 4 then 4		--возврат с розничных продаж по уценке
	--поставки
	when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (1,9) then 8								--поставки внешние от поставщика и РЦ
	when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (5) and P.OperationStatusId=3 then 9		--поставки излишков (по инвентаризации)
    when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (5) and P.OperationStatusId=1 then 10		--поставки излишков для корректировки необработанных продаж (по инвентаризации)
    when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (2,3,4,6,7,8,10,11,12,13,14,15) then 11	--прочие поставки (внутренние от магазинов, собственное производство и др.)
else 14 end as ForecastOperationTypeId, --сумма всех прочих операций с плюсом
sum(Qty) as Qty
from [SQL-STORE].BackStore.dbo.OperationsPart P (nolock) 
join [SQL-STORE].BackStore.dbo.EntOperationTypes T (nolock) on T.OperationTypeID=P.OperationTypeId 
left join [SQL-STORE].BackStore.dbo.Contractors C (nolock) on P.CounteragentId=C.ContractorId 
where P.ShopId in (250,248,116,27)
and P.Date between @DateBegin and @DateEnd
and T.DSign = 1
group by ShopId, Date, ItemId, 
case 
	--продажи	
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (3,204,302) and P.OperationStatusId <> 4 then 2	--возврат с розничных продаж без уценки и необработки
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (3,204,302) and P.OperationStatusId = 4 then 4		--возврат с розничных продаж по уценке
	--поставки
	when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (1,9) then 8								--поставки внешние от поставщика и РЦ
	when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (5) and P.OperationStatusId=3 then 9		--поставки излишков (по инвентаризации)
    when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (5) and P.OperationStatusId=1 then 10		--поставки излишков для корректировки необработанных продаж (по инвентаризации)
    when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (2,3,4,6,7,8,10,11,12,13,14,15) then 11	--прочие поставки (внутренние от магазинов, собственное производство и др.)
else 14 end

----- Все РАСХОДНЫЕ операции
--insert into dbo.ForecastOperationsPart (ShopId,Date,ItemId,ForecastOperationTypeId,Qty)
select P.ShopId, P.Date, P.ItemId, 
case 
	--продажи
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (2,203,321) and P.OperationStatusId <> 4 then 1	--розничные продажи без уценки и необработки
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (2,203,321) and P.OperationStatusId = 4 then 3		--розничные продажи по уценке
	when T.OperationTypeID in (10) then 5																		--розничные продажи по необработке
	when T.OperationTypeGroupID = 6 then 6																		--розничные продажи по необработке, скорректированные в учет (по инвентаризации)
	when T.OperationTypeGroupID = 3 and C.ContractorTypeId in (3) then 7										--оптовые продажи
	--списания
	when T.OperationTypeID in (8) then 12																		--списание недостатка (по инвентаризации)
	when T.OperationTypeID in (16,64,74) then 13																--списания по сроку годности/порче	
else 15 end as ForecastOperationTypeId, --сумма всех прочих операций с минусом
sum(Qty) as Qty
from [SQL-STORE].BackStore.dbo.OperationsPart P (nolock) 
join [SQL-STORE].BackStore.dbo.EntOperationTypes T (nolock) on T.OperationTypeID=P.OperationTypeId 
left join [SQL-STORE].BackStore.dbo.Contractors C (nolock) on P.CounteragentId=C.ContractorId 
where P.ShopId in (250,248,116,27)
and P.Date between @DateBegin and @DateEnd
and T.DSign = -1
group by ShopId, Date, ItemId, 
case 
	--продажи
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (2,203,321) and P.OperationStatusId <> 4 then 1	--розничные продажи без уценки и необработки
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (2,203,321) and P.OperationStatusId = 4 then 3		--розничные продажи по уценке
	when T.OperationTypeID in (10) then 5																		--розничные продажи по необработке
	when T.OperationTypeGroupID = 6 then 6																		--розничные продажи по необработке, скорректированные в учет (по инвентаризации)
	when T.OperationTypeGroupID = 3 and C.ContractorTypeId in (3) then 7										--оптовые продажи
	--списания
	when T.OperationTypeID in (8) then 12																		--списание недостатка (по инвентаризации)
	when T.OperationTypeID in (16,64,74) then 13																--списания по сроку годности/порче	
else 15 end


--====================== Исполнение заказов =============================
--- Удаление
--delete from dbo.OrderSupply where FactSupplyDate >= @OperReloadDate

--- Добавление
--insert into dbo.OrderSupply (OrderId,ShopId,ItemId,FactSupplyDate,FactQty)
select P.ParentDocNum, P.ShopId, P.ItemId, P.DATE, sum(P.Qty) as Qty
from [SQL-STORE].BackStore.dbo.OperationsPart P (nolock) 
join [SQL-STORE].BackStore.dbo.EntOperationTypes T (nolock) on T.OperationTypeID=P.OperationTypeId 
where P.ShopId in (250,248,116,27)
and P.Date between @DateBegin and @DateEnd
and T.DSign = 1
and T.OperationTypeGroupID = 1
and ISNULL(P.ParentDocNum,0)<>0
group by P.ParentDocNum, P.ShopId, P.ItemId, P.DATE 

-- Исправления кода заказа в связи с переносом в ЦО
--update dbo.OrderSupply set OrderId = T.OrderId
--from dbo.OrderSupply O
--join
--(select ShopId, OrderDate, OrderId, ShopOrderId 
--from DL580G2.BaseOrders.dbo.Orders H (nolock) 
--where OrderDate>='2013.12.01' and isnull(ShopOrderId,0)<>0 and OrderId<>ShopOrderId) as T
--on T.ShopId=O.ShopId and O.OrderId=T.ShopOrderId

----====================== Запись лога обновления =========================
--insert into UpdateOperationsLog (ShopId, Date, StartDate, FinishStatus)
--select ShopId, GETDATE(), @OperReloadDate, 1
--from dbo.EntShops 
--where ShopId in (select ShopId from ShopDataIntegration)

----====================== Статус наличия данных ==========================
--delete from OperationsPartStatus  where Date>=@OperReloadDate

--insert into OperationsPartStatus (ShopId, Date, OperationTypeForStatus, LoadingStatus)
--select distinct ShopId, Date, 1, 1 from dbo.ForecastOperationsPart where Date>=@OperReloadDate order by ShopId, Date

--insert into OperationsPartStatus (ShopId, Date, OperationTypeForStatus, LoadingStatus)
--select distinct ShopId, Date, 2, 1 from dbo.ForecastOperationsPart where Date>=@OperReloadDate order by ShopId, Date

