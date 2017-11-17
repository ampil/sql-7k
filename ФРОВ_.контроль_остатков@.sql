/*Заявка без номера*/
/*Запуск с [sql-store]; шаги 1-3 занимают 04:02*/
declare @ReportDate date = convert(date,getdate())

--(1) Выбор ЕТС из группы ФРОВ (1)
DECLARE @itemid TABLE (itemid INT, ItemName nvarchar(255))

insert into @itemid
select itemid, ItemName
from [BackStore].[dbo].[EntItems] t1
where [IdLevel_2] =16 --Категория "Овощи, фрукты"
	and not ItemName like 'Удалено%'


--(2) Средние продажи и поставки за 7 дней; 02:36--
DECLARE @Money1 TABLE ([ShopId] INT, ItemId INT, Sales decimal(18,2), Supply decimal(18,2))

insert into @Money1
SELECT t1.[ShopId]
		,t1.[ItemId]
		,sum([Sale])/7 as Sales --Средние продажи
		,SUM(Supply) as Supply --Получено
FROM spsssql.[FORECAST].[dbo].[t_SupplySale] t1
join @itemid t2 on t2.ItemId=t1.ItemId
where t1.[Date] >= DATEADD(day,-7,@ReportDate)
group by t1.[ShopId],t1.[ItemId]


DECLARE @Money TABLE ([ShopId] INT, ItemId INT, Sales decimal(18,2), Supply decimal(18,2))

INSERT INTO @Money
select t1.* from @Money1 t1
join @itemid t2 on t2.ItemId=t1.ItemId


-- (3) Остатки; 00:02 с сервера 
DECLARE @SqlString2 NVARCHAR(MAX)
DECLARE @Rest2 TABLE (shopid INT, itemid INT, Qty decimal(19,4))

SET @SqlString2 = '
SELECT * FROM OPENQUERY( [spsssql],''
select t1.ShopId, t1.ItemId, t1.Qty
from [FORECAST].[dbo].[RestDataShopItem]  t1
where t1.Date=convert(date,getdate())
order by t1.ShopId, t1.ItemId'') a'
       
INSERT INTO @Rest2
EXEC (@SqlString2)


DECLARE @Rest TABLE (shopid INT, itemid INT, Qty decimal(19,4))

INSERT INTO @Rest
select t1.* from @Rest2 t1
join @itemid t2 on t2.ItemId=t1.ItemId


-- (4) Заказы; 06:31
declare @Orders2 TABLE ([ShopId] INT, ItemId INT, OrderDate date,  Ordered decimal(18,2))

insert into @Orders2
SELECT 
		t1.ShopId
		,t1.ItemId --Код ЕТС
		,t1.OrderDate
		,sum(case when t1.DeliveryDate<=@ReportDate then t1.ShopOrderedQty else 0 end) as Ordered --Заказано
		--,SUM(t2.[ReceivedQty]) as [ReceivedQty] --Получено по закзам
FROM openquery(dl580g2,'select ShopId, t2.ItemId, OrderDate, DeliveryDate, ShopOrderedQty from [BaseOrders].[dbo].[Orders] t1
join [BaseOrders].[dbo].[OrdersItems] t2 on t2.OrderId=t1.OrderId
join Orders.dbo.Items i on t2.itemid=i.itemid
join orders.dbo.fngetcategoryfulllist(3) f on i.marketcategoryid=f.idlevel_5 and idlevel_2=16
where t1.OrderDate>=DATEADD(d,-2,convert(Date,getdate())) and t1.[OrderStatusId]=3') t1
group by t1.ShopId
		,t1.ItemId
		,t1.OrderDate
		

declare @Orders TABLE ([ShopId] INT, ItemId INT, Ordered decimal(18,2), Avail INT)

insert into @Orders
select t1.ShopId, t1.Itemid, sum(isnull(t1.Ordered,0)) as Ordered
,SUM(case when Ordered is null then 0 when t1.ItemId is not null then 1 else 0 end) as Avail --Доступно к заказу
from @Orders2 t1
right join @itemid t2 on t2.itemid=t1.itemid
group by t1.ShopId, t1.Itemid


-- (5) Дата проставления товара в матрицу  
--[dl580g2].dbo.Orders.fnGetAssortmentStates


-- (5) Совместно --
select t1.Shopid, t1.itemId
	, 0 as MatrixDate , t2.Qty as CurrentRest
	,(case when t1.Sales = 0 then null else t2.Qty/t1.Sales end) as Stock
	, t1.Sales, t3.Avail, t3.Ordered, t1.Supply 
	,(case when t3.Ordered = 0 then -1 when t1.Supply/t3.Ordered >1 then 1 else t1.Supply/t3.Ordered end) as Perc
into #Result
from @Money t1
full outer join @Rest t2 on t1.itemid=t2.itemid and t1.ShopId=t2.ShopId
full outer join @Orders t3 on t1.itemid=t3.itemid and t1.ShopId=t3.ShopId




/*

declare @Orders TABLE ([ShopId] INT, ItemId INT, Ordered decimal(18,2), Avail INT)

insert into @Orders
select a.ShopId, a.Itemid, sum(isnull(a.Ordered,0)) as Ordered
,SUM(case when Ordered is null then 0 when a.ItemId is not null then 1 else 0 end) as Avail --Доступно к заказу
from 
	(SELECT 
		t1.ShopId
		,t1.ItemId --Код ЕТС
		,t1.OrderDate
		,sum(case when t1.DeliveryDate<=@ReportDate then t1.ShopOrderedQty else 0 end) as Ordered --Заказано
		--,SUM(t2.[ReceivedQty]) as [ReceivedQty] --Получено по закзам
FROM openquery(dl580g2,'select ShopId, t2.ItemId, OrderDate, DeliveryDate, ShopOrderedQty from [BaseOrders].[dbo].[Orders] t1
join [BaseOrders].[dbo].[OrdersItems] t2 on t2.OrderId=t1.OrderId
join Orders.dbo.Items i on t2.itemid=i.itemid
join orders.dbo.fngetcategoryfulllist(3) f on i.marketcategoryid=f.idlevel_5 and idlevel_2=16
where t1.OrderDate>=DATEADD(d,-2,convert(Date,getdate())) and t1.[OrderStatusId]=3') t1
group by t1.ShopId
		,t1.ItemId
		,t1.OrderDate) a
right join @itemid t2 on t2.itemid=a.itemid
group by a.ShopId, a.Itemid	
*/