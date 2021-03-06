/*Заявка №671882*/ --Запуск с DL580G2
declare @delta int = 3 --Количество дней, на которые система смотрит "назад" от даты воза товара поставщиком
declare @CurDate date = convert(date,getdate()) --'2015-02-20'

/*Товары, участвующие в акции*/
IF OBJECT_ID('tempdb..#Promotions') IS NOT NULL BEGIN DROP TABLE #Promotions Print 'Deleted #Promotions' END

SELECT t1.[PromotionId], t1.[Name] as PromoName
	, t4.Shopid
	, t2.[ItemId]
	, t3.ContractorId as ContractorId
	, convert(date,t1.DateBegin) as PromoDateBegin
	, convert(date,t3.[SupplyDateBegin]) as [SupplyDateBegin]
    , convert(date,t3.[SupplyDateEnd]) as [SupplyDateEnd]
    --, t5.[OrderDate]
  into #Promotions
  FROM [Orders].[dbo].[Promotions] t1
  join [Orders].[dbo].[PromotionItems] t2 on t2.[PromotionId]=t1.[PromotionId]
  join [Orders].[dbo].[PromotionShops] t4 on t4.[PromotionId]=t1.[PromotionId]
  join [Orders].[dbo].[PromotionItemSupplies] t3 on t3.[PromotionItemId]=t2.[PromotionItemId]
  --join [BaseOrders].[dbo].[Orders] t5 on t5.[ShopId]=t4.[ShopId] and t5.OrderDate between dateadd(day,-3,t3.[SupplyDateBegin]) and t1.DateBegin
  --join [BaseOrders].[dbo].[OrdersItems] t6 on t6.[OrderId]=t5.[OrderId] and t6.[ItemId]=t2.ItemId
where t1.TypeId=4 and t1.Name like '%ШОК%' --п.1 ТЗ
		and getdate() between dateadd(day,@delta,t3.[SupplyDateBegin]) and t1.DateBegin --п.2 ТЗ

/*Заказы (подтвержденные или отправленные)*/ --30881
IF OBJECT_ID('tempdb..#Orders') IS NOT NULL BEGIN DROP TABLE #Orders Print 'Deleted #Orders' END

select ors.Shopid, ori.ItemId, ors.[ContractorId]
		,ors.[OrderDate], ors.[DeliveryDate]
		,ors.[DeliveryDateNext]
into #Orders
from [BaseOrders].[dbo].[Orders] ors
join [BaseOrders].[dbo].[OrdersItems] ori on ori.OrderId=ors.OrderId
join #Promotions tt on tt.Shopid=ors.Shopid and tt.ItemId=ori.ItemId and tt.[ContractorId]=ors.[ContractorId] 
						and ors.[DeliveryDate] between tt.[SupplyDateBegin] and tt.PromoDateBegin --dateadd(day,-3,tt.[SupplyDateBegin])
						and ors.OrderDate=convert(date,getdate()) 
where ors.[OrderDate]=convert(date,getdate())  and 
ors.[OrderStatusId] in (1,3)

/*Дата следующего заказа и поставки*/
IF OBJECT_ID('tempdb..#Schedule') IS NOT NULL BEGIN DROP TABLE #Schedule Print 'Deleted #Schedule' END

select d1.* ,d2.DeliveryDate
into #Schedule
from
	(SELECT t1.[ShopId] ,t1.[ContractorId] ,[FrameworkId]
			,min([OrderDate]) as mOrderDate
	FROM [BaseOrders].[dbo].[OrdersSchedules] t1
	join #Promotions t2 on t2.ShopId=t1.ShopId and t2.ContractorId=t1.ContractorId
	where [OrderDate] >CONVERT(date,GETDATE())
	group by t1.[ShopId] ,t1.[ContractorId] ,[FrameworkId]
	) d1
join [BaseOrders].[dbo].[OrdersSchedules] d2 on d2.ContractorId=d1.ContractorId and d2.FrameworkId=d1.FrameworkId and d2.ShopId=d1.ShopId and d2.OrderDate=d1.mOrderDate


/*Выборка акционных товаров, которые не были заказаны у поставщика с [Дата воза товара - 3 дня] до [Дата начала акции]*/
--На создание макетов
select CONVERT(date,getdate()) as [Дата отчета], t1.PromotionId as [Код акции], t1.PromoName as [Название акции], t1.PromoDateBegin as [Начало акции]
	,t1.ShopId as [Код магазина], Sh.name as [Магазин]
	,t1.ItemId as [Код ЕТС], It.Name as [Наименование], t1.ContractorId as [Код поставщика], CC.[Name] as [Поставщик]
	 ,sd.mOrderDate as [Дата следующего заказа по графику]
	 ,sd.DeliveryDate as [Дата следующей поставки]
	 --,dateadd(day,3,convert(date,getdate())) as DeliveryDate --п.4.b ТЗ
from #Promotions t1
left join #Orders t2 on t1.Shopid=t2.ShopId and t1.ItemId=t2.Itemid and t1.ContractorId=t2.ContractorId
join [Orders].[dbo].[Shops] Sh on Sh.ShopId=t1.ShopId
join [Orders].[dbo].[Items] It on It.ItemId=t1.Itemid
left join [Orders].[dbo].[Contractors] CC on CC.ContractorId=t1.ContractorId
left join #Schedule sd on sd.ContractorId=t1.ContractorId and sd.ShopId=t1.ShopId
where t2.ShopiD is null
order by Sh.name, It.Name


--Для отчета по кол-ву пустографок
select d.ShopId as [Код магазина], Sh.name as [Магазин], count(*) as [Кол-во пустографок]
from
	(
	select t1.PromotionId, t1.ShopId, t1.ItemId, t1.ContractorId
		 ,dateadd(day,3,convert(date,getdate())) as DeliveryDate --п.4.b ТЗ
	from #Promotions t1
	left join #Orders t2 on t1.Shopid=t2.ShopId and t1.ItemId=t2.Itemid and t1.ContractorId=t2.ContractorId
	where t2.ShopiD is null
	) d
join [Orders].[dbo].[Shops] Sh on Sh.ShopId=d.ShopId
group by d.ShopId, Sh.name
order by Sh.name asc