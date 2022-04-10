declare @showall int=0;--1 is true
declare @recno int=1;--2nd parameter, this assumes values 1,2,3------------------------------------------------------
declare @edate date = '2021-06-30';--this is a parameter-----------------------------------------------------------
-----
declare @bdate date = '2015-06-30';--this is fixed, not a parameter
declare @table Table (recno int,acctno varchar(5), pledget varchar(2));
insert into @table values (1,'12000','GD');
insert into @table values (1,'12000','FP');
insert into @table values (2,'12070','DP');
insert into @table values (3,'12020','SP');


declare @pledge varchar(10)='0002327081'; --for testing
declare @table2 Table (
	[X] varchar(1),
	[Fund] varchar(4),[Fund Name] varchar(255),
	[Pledge Number] varchar(10), [Pledge Type] varchar(2),
	[Donor Number] varchar(10),
	[Recon Date] date, 
	--[Date of Record] date, 
	--[Cancelled Date] date, [Paid Date] date,
	[Advance] decimal(15,2), [BBFE] decimal(15,2), [Diff] decimal(15,2),
	[Advance Future] decimal(15,2), [BBFE Future] decimal(15,2), [Diff Future] decimal(15,2), 
	[Comment] varchar(255)
	);


insert into @table2
select
'X'
,fund.fund_number [Fund]
,fund.fund_description [Fund Name]
,trx.xsrc_pledge_num [Pledge Number]
,null [Pledge Type]
,null [Donor Number]
,@edate [Recon Date]
--,null [Date of Record]
--,null [Cancelled Date]
--,null [Paid Date]
,0.0 [Advance]
,sum(trx.amount) [BBFE]
,0.0 [Diff]
,0.0 [Advance Future]
,0.0 [BBFE Future]
,0.0 [Diff Future]
,'' [Comment]
from uo_fund fund
join UO_GL_TRANSACTION trx on fund.fund_id=trx.fund_id
join acctetl.dbo.uo_batch batch on batch.batch_id=trx.batch_id
where 
trx.post_date between @bdate and @edate 
and left(trx.account_number,5) in (select distinct acctno from @table t where t.recno=@recno)
and trx.xsrc_pledge_num IS NOT NULL
and fund.fund_number not in ('7000')
group by
fund.fund_number
,fund.fund_description
,trx.xsrc_pledge_num
having
sum(trx.amount)<>0.0
;

insert into @table2
select
'X'
,fund.fund_number [Fund]
,fund.fund_description [Fund Name]
,trx.xsrc_pledge_num [Pledge Number]
,null [Pledge Type]
,null [Donor Number]
,@edate [Recon Date]
--,null [Date of Record]
--,null [Cancelled Date]
--,null [Paid Date]
,0.0 [Advance]
,0.0 [BBFE]
,0.0 [Diff]
,0.0 [Advance Future]
,sum(trx.amount) [BBFE Future]
,0.0 [Diff Future]
,'' [Comment]
from uo_fund fund
join UO_GL_TRANSACTION trx on fund.fund_id=trx.fund_id
join acctetl.dbo.uo_batch batch on batch.batch_id=trx.batch_id
where 
trx.post_date>=@bdate
and left(trx.account_number,5) in (select distinct acctno from @table t where t.recno=@recno)
and trx.xsrc_pledge_num IS NOT NULL
and fund.fund_number not in ('7000')
group by
fund.fund_number
,fund.fund_description
,trx.xsrc_pledge_num
having
sum(trx.amount)<>0.0
;

insert into @table2
select
''
,[Fund],[Fund Name],[Pledge Number],[Pledge Type]
,[Donor Number]
,[Recon Date]
--,[Date of Record]
--,[Cancelled Date]
--,[Paid Date]
,sum([Advance]),sum([BBFE]),sum([Diff])
,sum([Advance Future]),sum([BBFE Future]),sum([Diff Future])
,[Comment]
from @table2
group by
[Fund],[Fund Name],[Pledge Number],[Pledge Type]
,[Donor Number]
,[Recon Date]
--,[Date of Record]
--,[Cancelled Date],[Paid Date]
,[Comment]
;
delete from @table2 where [X]='X';
-------------------------------------------------------------------------------------------
update @table2
set
[Pledge Type]=pbh.pledge_type_code,
[Advance]=pbh.pledge_balance
--[Date of Record]=pbh.date_of_record
from uo_pledge_balance_hist pbh
join @table2 on [Fund]=pbh.fund_number and [Pledge Number]=pbh.pledge_number
where
pbh.history_sequence=(select min(pbh2.history_sequence) from uo_pledge_balance_hist pbh2 
						where pbh2.fund_number=pbh.fund_number and pbh2.pledge_number=pbh.pledge_number
						and pbh2.date_of_record<=@edate)
;
update @table2
set
[Pledge Type]=pbh.pledge_type_code,
[Advance]=pbh.pledge_balance
--[Date of Record]=pbh.date_of_record
from uo_pledge_balance_hist pbh
join @table2 on [Pledge Number]=pbh.pledge_number
where
[Fund]='6716'
and pbh.history_sequence=(select min(pbh2.history_sequence) from uo_pledge_balance_hist pbh2 
						where pbh2.fund_number=pbh.fund_number and pbh2.pledge_number=pbh.pledge_number
						and pbh2.date_of_record<=@edate)
;
update @table2
set
[Pledge Type]=pbh.pledge_type_code,
[Advance Future]=pbh.pledge_balance
--[Date of Record]=pbh.date_of_record
from uo_pledge_balance_hist pbh
join @table2 on [Pledge Number]=pbh.pledge_number
where
[Fund]='6716'
and pbh.history_sequence=(select min(pbh2.history_sequence) from uo_pledge_balance_hist pbh2 
						where pbh2.fund_number=pbh.fund_number and pbh2.pledge_number=pbh.pledge_number
						--and pbh2.date_of_record<=@edate
						)
;
----
update @table2
set
[Advance Future]=pbh.pledge_balance
from uo_pledge_balance_hist pbh
join @table2 on [Fund]=pbh.fund_number and [Pledge Number]=pbh.pledge_number
where
pbh.history_sequence=(select min(pbh2.history_sequence) from uo_pledge_balance_hist pbh2 
						where pbh2.fund_number=pbh.fund_number and pbh2.pledge_number=pbh.pledge_number)
;

----final stuff
update @table2 set [Diff]=[Advance]-[BBFE], [Diff Future]=[Advance Future]-[BBFE Future];
update @table2 set [Comment]=concat([Comment],'Fixed in future. ') where [Diff Future]=0 and [Diff]<>0;
update @table2 set [Comment]=concat([Comment],'Advance>BBFE. ') where [Advance]>[BBFE] and [Diff]<>0 and comment='';
--if not @showall=0 delete from @table2 where [Diff]=0 and patindex('%adjusted%', [Comment])=0;
if not @showall=1 delete from @table2 where [Diff]=0;
update @table2 set [Donor Number]=(select top(1) donor_id from uo_pledge_balance_hist upbh where [Pledge Number]=upbh.pledge_number
order by history_sequence);


select
*
from @table2
order by 2,4
;