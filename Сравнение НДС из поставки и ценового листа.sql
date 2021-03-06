/*Заявка №680825*/
/*Сравнение НДС из поставки и ценового листа*/

--Необходимо написать Sql-запрос к заявке на отчет 638874 для получения данных и сравнения ставок НДС
--Поля отчета:
--| Магазин | Номер поставки | Дата поставки | Код ЕТС | Наименование товара | НДС из поставки | НДС из ценового листа |
--В отчет выводить только расхождения в ставках НДС

/*Запуск с SQL-STORE*/
/*C 01.01.2015 - 3813 записей, время исполнения - 32:14 */ 

declare @DateFrom date = convert(date,'2015-04-12')
declare @DateTo date = convert(date,'2015-04-19')

SELECT t2.[ShopId] as [Код магазина]
	,ES.ShopName as [Магазин]
	,t2.ParentDocNum as [Номер поставки]
	,convert(date,t2.[Date]) as [Дата поставки]
	,t2.[ItemId] as [Код ЕТС]
	,EI.ItemName as [Наименование]
	,t2.[InTaxRt] as [НДС из поставки]
	,convert(decimal(4,2),t1.VAT*100) as [НДС из ценового листа]
FROM openquery(dl580g2,'SELECT t2.ContractorId
							  ,[ItemId]
							  ,[VAT]
						  FROM [dl580g2].[Orders].[dbo].[Assortment] t1
						  join [dl580g2].[Orders].[dbo].[OrganizationsMain] t2 on t1.OrganizationId=t2.Id
						  where t2.ContractorId is not null
						') t1
join [BackStore].[dbo].[OperationsPart] t2 on t2.[ItemId]=t1.itemid and t2.[CounteragentId]=t1.ContractorId
join [BackStore].dbo.EntItems EI on EI.ItemID=t2.[ItemId]
join [BackStore].dbo.EntShops ES on ES.ShopID=t2.ShopId
where  t2.[OperationTypeId]=1 and t2.[OperationStatusId]=1 --Поставки
		and t2.[InTaxRt]<>convert(decimal(4,2),t1.VAT*100) --Вывод только неодинаковых НДС
		and convert(date,t2.[Date]) between @DateFrom and @DateTo --'2015-01-01'
Order by t2.[ShopId], t2.[ItemId], t2.[Date] desc

  
  