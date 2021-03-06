USE [BaseOrders]
GO
/****** Object:  StoredProcedure [dbo].[DistrList]    Script Date: 03/19/2015 16:47:04 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[DistrList] (
   @RawOrderId        NVARCHAR(4000) = 548)
AS
SET NOCOUNT ON


/*Заявка №674748*/
/*Отчет по формированию разнарядок*/
/*Запуск с [DL580G2]*/


--declare @RawOrderId varchar(100) = '548, 549'
--DECLARE @SqlString NVARCHAR(MAX)

/*Создание таблицы-фильтра с номерами разнарядкок*/
IF OBJECT_ID('tempdb..#RawOrders') IS NOT NULL BEGIN DROP TABLE #RawOrders Print 'Deleted #RawOrders' END	
CREATE TABLE #RawOrders (RawOrderId INT, CreateDate DATETIME)

DECLARE @SQLString NVARCHAR(4000)
SET @SQLString='
SELECT RawOrderId, CreateDate FROM [BaseOrders].[dbo].[RawOrders] RO WHERE RO.RawOrderId IN ('+@RawOrderId+')'

INSERT INTO #RawOrders
EXEC sp_executesql @SQLString


/*Исполнение заказов*/
IF OBJECT_ID('tempdb..#OrderId') IS NOT NULL BEGIN DROP TABLE #OrderId Print 'Deleted #OrderId' END	

CREATE TABLE #OrderId (OrderId INT, ItemId INT, ShopId INT)

INSERT INTO #OrderId
SELECT t1.OrderId, t1.ItemId, t1.ShopId
from [BaseOrders].[dbo].[RawOrdersItems] t1
join [BaseOrders].[dbo].[RawOrders] t2 on t2.RawOrderId=t1.RawOrderId and t1.[ContractorId]=t2.[ContractorId]
where t1.RawOrderId in (SELECT RawOrderId from #RawOrders)

DECLARE @MinDate NVARCHAR(8)
SELECT @MinDate=convert(NVARCHAR(8),MIN(CreateDate),112) FROM #RawOrders

IF OBJECT_ID('tempdb..#Fact') IS NOT NULL BEGIN DROP TABLE #Fact Print 'Deleted #Fact' END	
/*
select t1.* 
into #Fact
from spsssql.[FORECAST].[dbo].[OrderSupply] t1 --Результат импорта с SQL-STORE на SPSSSQL
join #OrderId t2 on t2.OrderId=t1.OrderId and t2.Shopid=t1.ShopId and t2.Itemid=t1.Itemid  
*/
--Вариант с SPSSSQL - дольше на 5 сек (с двумя разнарядками)

CREATE TABLE #Fact (OrderId INT, ShopId INT, ItemId INT, FactSupplyDate DATETIME, FactQty DECIMAL(19,3), Cost DECIMAL(18,2))

SET @SQLString='
select P.ParentDocNum as OrderId, P.ShopId, P.ItemId, P.DATE as FactSupplyDate, sum(P.Qty) as FactQty, SUM(p.InAmt)/SUM(p.Qty) Cost
FROM openrowset(''sqlncli'',''Sql-Store'';''cognoswh'';''whdatabase'',''SELECT ParentDocNum
                                ,ShopId
                                ,ItemId
                                ,DATE
                                ,Qty
                                ,InAmt
                          FROM   BackStore.dbo.OperationsPart (NOLOCK)
                          WHERE  Date >= '''''+@MinDate+'''''
                                 AND OperationTypeID = 1
                                 AND OperationStatusId = 1
                                 AND ISNULL(ParentDocNum, 0) != 0'') p
join #OrderId t2 on t2.OrderId=P.ParentDocNum and t2.Shopid=P.ShopId and t2.Itemid=P.Itemid
group by P.ParentDocNum, P.ShopId, P.ItemId, P.DATE '
--PRINT @SQLString

INSERT INTO #Fact
EXEC sp_executesql @SQLString

/*Отчет*/
SELECT t1.[RawOrderId] as [Номер разнарядки]
  ,t1.[OrderId] as [Номер заказа]
  ,t1.[ContractorId] as [Код поставщика]
  ,CC.Name as [Поставщик]
  ,t1.[ShopId] as [Код магазина]
  ,Sh.Name as [Адес магазина]
  , [OrderStatuses].Name as [Текущий статус заказа]
  , ors.OrderDate as [Дата отправки заказа]
  ,(case when ors.OrderStatusId=3 then ISNULL(ors.[AdjustedDeliveryDate],t1.[DeliveryDate]) else t1.[DeliveryDate] end) as [Дата доставки заказа]
  ,t1.[ItemId] as [Код ЕТС]
  ,It.Name as [Наименование]
  ,t1.[OrderedQty]as [Заказанное кол-во] -- == [OrderedQty_Original] и ori.OrderedQty
  ,(case when ors.OrderStatusId=3 then ISNULL(ori.AdjustedQty,t1.OrderedQty) else ori.AdjustedQty end) as [Подтвержденное кол-во]
  
  ,Fact.[FactQty] as [Фактически поставлено]
  ,Fact.Cost AS [Цена поставки]
  ,Fact.[FactSupplyDate] as [Дата факт. поставки]
FROM [BaseOrders].[dbo].[RawOrdersItems] t1 
join [BaseOrders].[dbo].[RawOrders] t2 on t2.RawOrderId=t1.RawOrderId and t1.[ContractorId]=t2.[ContractorId]
join [Orders].[dbo].[Shops] Sh on Sh.ShopId=t1.ShopId
join [Orders].[dbo].[Items] It on It.ItemId=t1.Itemid
left join [Orders].[dbo].[Contractors] CC on CC.ContractorId=t1.ContractorId
left join [BaseOrders].[dbo].[OrdersItems] Ori on Ori.OrderId=t1.OrderId and Ori.ItemId=t1.ItemId
left join [BaseOrders].[dbo].[Orders] Ors on Ors.OrderId=t1.OrderId and Ors.ShopId=t1.ShopId
join [BaseOrders].[dbo].[OrderStatuses] on [OrderStatuses].OrderStatusId=Ors.OrderStatusId
left join #Fact Fact ON Fact.ShopId = t1.ShopId AND Fact.ItemId = t1.ItemId AND Fact.OrderId = t1.OrderId 
where t1.RawOrderId in (SELECT RawOrderId from #RawOrders)
order by t1.[RawOrderId], t1.[OrderId], Sh.Name, It.Name
