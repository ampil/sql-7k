USE BackStore
/*Заявка без номера*/
/*Запуск с [sql-store]; все шаги занимают 11 минут*/

--(1) Выбор ЕТС из группы ФРОВ (1)
IF OBJECT_ID('tempdb..#itemid') IS NOT NULL BEGIN DROP TABLE #itemid Print 'Deleted #itemid' END
CREATE TABLE #itemid (itemid INT, ItemName nvarchar(255))

insert into #itemid
select itemid, ItemName
from [BackStore].[dbo].[EntItems] t1 (NOLOCK) 
where [IdLevel_2] =16 --Категория "Овощи, фрукты"
	and not ItemName like 'Удалено%'
CREATE INDEX I_ItemID ON #itemid (ItemId)
PRINT GETDATE()


--(2) Средние продажи и поставки за 7 дней; 02:36--
IF OBJECT_ID('tempdb..#Money1') IS NOT NULL BEGIN DROP TABLE #Money1 Print 'Deleted #Money1' END
CREATE TABLE #Money1 ([ShopId] INT, ItemId INT, Sales decimal(18,2), Supply decimal(18,2))

insert into #Money1
SELECT * --Получено
FROM OpenQuery( spsssql,'SELECT t.[ShopId]
                               ,t.[ItemId]
                               ,SUM([Sale]) / 7 AS Sales --Средние продажи
                               ,SUM(Supply) AS Supply
                         FROM   [FORECAST].[dbo].[t_SupplySale] (NOLOCK) t
                                JOIN [FORECAST].[dbo].[EntItems] t1(NOLOCK)
                                     ON  t.itemid = t1.itemid
                                     AND [IdLevel_2] = 16
                                     AND t.[Date] >= DATEADD(DAY, -7, CONVERT(Date, GETDATE())) --включая сегодня может быть 8
                         GROUP BY
                                t.[ShopId]
                               ,t.[ItemId]') t1

CREATE INDEX M_ShopId1 ON #Money1 (ShopId)
CREATE INDEX M_ItemId1 ON #Money1 (ItemId)
PRINT GETDATE()


IF OBJECT_ID('tempdb..#Money') IS NOT NULL BEGIN DROP TABLE #Money Print 'Deleted #Money' END
CREATE TABLE #Money ([ShopId] INT, ItemId INT, Sales decimal(18,2), Supply decimal(18,2))

INSERT INTO #Money
select t1.* from #Money1 t1
join #itemid t2 on t2.ItemId=t1.ItemId

CREATE INDEX M_ShopId ON #Money (ShopId)
CREATE INDEX M_ItemId ON #Money (ItemId)
PRINT GETDATE()


-- (3) Остатки; 00:02 с сервера 
DECLARE @SqlString2 NVARCHAR(MAX)
IF OBJECT_ID('tempdb..#Rest2') IS NOT NULL BEGIN DROP TABLE #Rest2 Print 'Deleted #Rest2' END
CREATE TABLE #Rest2 (shopid INT, itemid INT, Qty decimal(19,4))

SET @SqlString2 = '
SELECT * FROM OPENQUERY( [spsssql],''
select t1.ShopId, t1.ItemId, isnull(t1.Qty,0) as Qty
from [FORECAST].[dbo].[RestDataShopItem]  t1 (nolock) 
where t1.Date=convert(date,getdate())
order by t1.ShopId, t1.ItemId'') a'
       
INSERT INTO #Rest2
EXEC (@SqlString2)
CREATE INDEX R_ShopId2 ON #Rest2 (ShopId)
CREATE INDEX R_itemid2 ON #Rest2 (itemid)
PRINT GETDATE()


IF OBJECT_ID('tempdb..#Rest') IS NOT NULL BEGIN DROP TABLE #Rest Print 'Deleted #Rest' END
CREATE TABLE #Rest (shopid INT, itemid INT, Qty decimal(19,4))

INSERT INTO #Rest
select t1.* from #Rest2 t1
where t1.itemid in (select ItemId from #itemid)

CREATE INDEX R_ShopId ON #Rest (ShopId)
CREATE INDEX R_itemid ON #Rest (itemid)
PRINT GETDATE()


-- (4) Заказы; 06:31
IF OBJECT_ID('tempdb..#Orders2') IS NOT NULL BEGIN DROP TABLE #Orders2 Print 'Deleted #Orders2' END
CREATE TABLE #Orders2 ([ShopId] INT, ItemId INT, OrderDate date,  Ordered decimal(18,2))

insert into #Orders2
SELECT 
		t1.ShopId
		,t1.ItemId --Код ЕТС
		,t1.OrderDate
		,sum(case when t1.DeliveryDate<=convert(date,getdate()) then t1.ShopOrderedQty else 0 end) as Ordered --Заказано
		--,SUM(t2.[ReceivedQty]) as [ReceivedQty] --Получено по закзам
FROM openquery(dl580g2,'select ShopId, t2.ItemId, OrderDate, DeliveryDate, ShopOrderedQty from [BaseOrders].[dbo].[Orders] t1 (nolock) 
join [BaseOrders].[dbo].[OrdersItems] t2 (nolock) on t2.OrderId=t1.OrderId
join Orders.dbo.Items i (nolock) on t2.itemid=i.itemid
join orders.dbo.fngetcategoryfulllist(3) f on i.marketcategoryid=f.idlevel_5 and idlevel_2=16
where t1.OrderDate>=DATEADD(d,-7,convert(Date,getdate())) and t1.[OrderStatusId]=3') t1
group by t1.ShopId
		,t1.ItemId
		,t1.OrderDate
		
CREATE INDEX O_ShopId2 ON #Orders2 (ShopId)
CREATE INDEX O_itemid2 ON #Orders2 (itemid)
CREATE INDEX O_OrderDate ON #Orders2 (OrderDate)
PRINT GETDATE()


IF OBJECT_ID('tempdb..#Orders') IS NOT NULL BEGIN DROP TABLE #Orders Print 'Deleted #Orders' END
CREATE TABLE #Orders ([ShopId] INT, ItemId INT, Ordered decimal(18,2), Avail INT)

insert into #Orders
select t1.ShopId, t1.Itemid, sum(isnull(t1.Ordered,0)) as Ordered
,SUM(case when Ordered is null then 0 --В заказе не было
	when t1.ItemId is not null then 1 --В заказе было, и могло быть заказано любое число (в т.ч. 0)
	else 0 end) as Avail --Доступно к заказу
from #Orders2 t1
right join #itemid t2 on t2.itemid=t1.itemid
group by t1.ShopId, t1.Itemid
CREATE INDEX O_ShopId ON #Orders (ShopId)
CREATE INDEX O_itemid ON #Orders (itemid)
PRINT GETDATE()


-- (5) Дата проставления товара в матрицу  
IF OBJECT_ID('tempdb..#MatrixHistory') IS NOT NULL BEGIN DROP TABLE #MatrixHistory Print 'Deleted #MatrixHistory' END	
CREATE TABLE #MatrixHistory (CreateTime Date, ShopId INT, ItemId INT)

insert into #MatrixHistory
select AM.CreateTime, AM.ShopId, AM.ItemId
from 
-- Товары на полках	
	(select SS.ShopId, SM.ItemId, SM.CreateTime
	from DL580G2.Orders.dbo.ShelfsShops SS (nolock)
	join DL580G2.Orders.dbo.Shelfs S (nolock) on SS.ShelfId=S.ShelfId
	join DL580G2.Orders.dbo.ShelfsMatrix SM (nolock) on SM.ShelfId=S.ShelfId
	join #itemid tt on tt.itemid=SM.ItemId
	group by SS.ShopId, SM.ItemId, SM.CreateTime
	)	as AM
group by AM.ShopId, AM.ItemId, AM.CreateTime
CREATE INDEX MH_ShopId ON #MatrixHistory (ShopId)
CREATE INDEX MH_itemid ON #MatrixHistory (itemid)
PRINT GETDATE()


-- (6) Совместно --
IF OBJECT_ID('tempdb..#Result') IS NOT NULL BEGIN DROP TABLE #Result Print 'Deleted #Result' END	

CREATE TABLE #Result (ShopId INT, ItemId INT, MatrixDate date, CurrentRest decimal(18,3), Stock decimal(18,1), Sales decimal(18,1), Avail INT, Ordered decimal(18,3), Supply decimal(18,3), Perc decimal(18,4))

insert into #Result
select t3.Shopid, t3.itemId
	, convert(date,t4.CreateTime) as MatrixDate , isnull(t2.Qty,0) as CurrentRest
	,(case when isnull(t2.Qty,0)=0 then 0 when t1.Sales = 0 then null else isnull(t2.Qty,0)/t1.Sales end) as Stock
	, isnull(t1.Sales,0) as Sales, isnull(t3.Avail,0) as Avail, isnull(t3.Ordered,0) as Ordered
	, isnull(t1.Supply,0) as Supply
	,(case when isnull(t3.Ordered,0) = 0 and isnull(t1.Supply,0)=0 then 0 
		when isnull(t3.Ordered,0) = 0 then 1 
		when t1.Supply/t3.Ordered >1 then 1 
		--when isnull(t1.Supply,0)=0 and isnull(t3.Ordered,0)>0 then -1 
		else isnull(t1.Supply,0)/isnull(t3.Ordered,0) end) as Perc
from #Money t1
right join #Orders t3 on t1.itemid=t3.itemid and t1.ShopId=t3.ShopId
left join #MatrixHistory t4 on t4.ShopId=t1.ShopId and t4.ItemId=t1.ItemId
left join #Rest t2 on t1.itemid=t2.itemid and t1.ShopId=t2.ShopId
--where t4.CreateTime is not null
PRINT GETDATE()


SELECT * FROM #Result
