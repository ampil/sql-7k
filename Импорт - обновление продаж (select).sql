--- ����������� ���� ����������
declare @OperReloadDate datetime
set @OperReloadDate = (select min(ReloadDate) from ShopdateReload)

----=============================== �������������� =======================
--- ��������
--delete from dbo.ForecastOperationsPart where Date >= @OperReloadDate

--- ���������� ������
declare @DateBegin datetime, @DateEnd datetime
set @DateBegin = @OperReloadDate
set @DateEnd = DateAdd(Day,-1,convert(varchar(10),GETDATE(),102))

----- ��� ��������� ��������
--insert into dbo.ForecastOperationsPart (ShopId,Date,ItemId,ForecastOperationTypeId,Qty)
select P.ShopId, P.Date, P.ItemId, 
case 
	--�������
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (3,204,302) and P.OperationStatusId <> 4 then 2	--������� � ��������� ������ ��� ������ � �����������
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (3,204,302) and P.OperationStatusId = 4 then 4		--������� � ��������� ������ �� ������
	--��������
	when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (1,9) then 8								--�������� ������� �� ���������� � ��
	when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (5) and P.OperationStatusId=3 then 9		--�������� �������� (�� ��������������)
    when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (5) and P.OperationStatusId=1 then 10		--�������� �������� ��� ������������� �������������� ������ (�� ��������������)
    when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (2,3,4,6,7,8,10,11,12,13,14,15) then 11	--������ �������� (���������� �� ���������, ����������� ������������ � ��.)
else 14 end as ForecastOperationTypeId, --����� ���� ������ �������� � ������
sum(Qty) as Qty
from [SQL-STORE].BackStore.dbo.OperationsPart P (nolock) 
join [SQL-STORE].BackStore.dbo.EntOperationTypes T (nolock) on T.OperationTypeID=P.OperationTypeId 
left join [SQL-STORE].BackStore.dbo.Contractors C (nolock) on P.CounteragentId=C.ContractorId 
where P.ShopId in (250,248,116,27)
and P.Date between @DateBegin and @DateEnd
and T.DSign = 1
group by ShopId, Date, ItemId, 
case 
	--�������	
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (3,204,302) and P.OperationStatusId <> 4 then 2	--������� � ��������� ������ ��� ������ � �����������
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (3,204,302) and P.OperationStatusId = 4 then 4		--������� � ��������� ������ �� ������
	--��������
	when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (1,9) then 8								--�������� ������� �� ���������� � ��
	when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (5) and P.OperationStatusId=3 then 9		--�������� �������� (�� ��������������)
    when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (5) and P.OperationStatusId=1 then 10		--�������� �������� ��� ������������� �������������� ������ (�� ��������������)
    when T.OperationTypeGroupID = 1 and C.ContractorTypeId in (2,3,4,6,7,8,10,11,12,13,14,15) then 11	--������ �������� (���������� �� ���������, ����������� ������������ � ��.)
else 14 end

----- ��� ��������� ��������
--insert into dbo.ForecastOperationsPart (ShopId,Date,ItemId,ForecastOperationTypeId,Qty)
select P.ShopId, P.Date, P.ItemId, 
case 
	--�������
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (2,203,321) and P.OperationStatusId <> 4 then 1	--��������� ������� ��� ������ � �����������
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (2,203,321) and P.OperationStatusId = 4 then 3		--��������� ������� �� ������
	when T.OperationTypeID in (10) then 5																		--��������� ������� �� �����������
	when T.OperationTypeGroupID = 6 then 6																		--��������� ������� �� �����������, ����������������� � ���� (�� ��������������)
	when T.OperationTypeGroupID = 3 and C.ContractorTypeId in (3) then 7										--������� �������
	--��������
	when T.OperationTypeID in (8) then 12																		--�������� ���������� (�� ��������������)
	when T.OperationTypeID in (16,64,74) then 13																--�������� �� ����� ��������/�����	
else 15 end as ForecastOperationTypeId, --����� ���� ������ �������� � �������
sum(Qty) as Qty
from [SQL-STORE].BackStore.dbo.OperationsPart P (nolock) 
join [SQL-STORE].BackStore.dbo.EntOperationTypes T (nolock) on T.OperationTypeID=P.OperationTypeId 
left join [SQL-STORE].BackStore.dbo.Contractors C (nolock) on P.CounteragentId=C.ContractorId 
where P.ShopId in (250,248,116,27)
and P.Date between @DateBegin and @DateEnd
and T.DSign = -1
group by ShopId, Date, ItemId, 
case 
	--�������
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (2,203,321) and P.OperationStatusId <> 4 then 1	--��������� ������� ��� ������ � �����������
	when T.OperationTypeGroupID = 2 and T.OperationTypeId in (2,203,321) and P.OperationStatusId = 4 then 3		--��������� ������� �� ������
	when T.OperationTypeID in (10) then 5																		--��������� ������� �� �����������
	when T.OperationTypeGroupID = 6 then 6																		--��������� ������� �� �����������, ����������������� � ���� (�� ��������������)
	when T.OperationTypeGroupID = 3 and C.ContractorTypeId in (3) then 7										--������� �������
	--��������
	when T.OperationTypeID in (8) then 12																		--�������� ���������� (�� ��������������)
	when T.OperationTypeID in (16,64,74) then 13																--�������� �� ����� ��������/�����	
else 15 end


--====================== ���������� ������� =============================
--- ��������
--delete from dbo.OrderSupply where FactSupplyDate >= @OperReloadDate

--- ����������
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

-- ����������� ���� ������ � ����� � ��������� � ��
--update dbo.OrderSupply set OrderId = T.OrderId
--from dbo.OrderSupply O
--join
--(select ShopId, OrderDate, OrderId, ShopOrderId 
--from DL580G2.BaseOrders.dbo.Orders H (nolock) 
--where OrderDate>='2013.12.01' and isnull(ShopOrderId,0)<>0 and OrderId<>ShopOrderId) as T
--on T.ShopId=O.ShopId and O.OrderId=T.ShopOrderId

----====================== ������ ���� ���������� =========================
--insert into UpdateOperationsLog (ShopId, Date, StartDate, FinishStatus)
--select ShopId, GETDATE(), @OperReloadDate, 1
--from dbo.EntShops 
--where ShopId in (select ShopId from ShopDataIntegration)

----====================== ������ ������� ������ ==========================
--delete from OperationsPartStatus  where Date>=@OperReloadDate

--insert into OperationsPartStatus (ShopId, Date, OperationTypeForStatus, LoadingStatus)
--select distinct ShopId, Date, 1, 1 from dbo.ForecastOperationsPart where Date>=@OperReloadDate order by ShopId, Date

--insert into OperationsPartStatus (ShopId, Date, OperationTypeForStatus, LoadingStatus)
--select distinct ShopId, Date, 2, 1 from dbo.ForecastOperationsPart where Date>=@OperReloadDate order by ShopId, Date

