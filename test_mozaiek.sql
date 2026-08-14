set feedback off termout off
--run under thudge@freepdb1
clear screen
--whenever oserror exit rollback;
--whenever sqlerror exit sql.sqlcode rollback;
--test de werking van Mozaiek
prompt installeer package mozaiek
@@mozaiek.pkd
prompt installeer package body mozaiek
@@mozaiek.pkb
set termout on
prompt test mozaiek
-- @@mosaic_testcase00.sql
@@mosaic_testcase01.sql
-- @@mosaic_testcase02.sql
-- @@mosaic_puzzelsport_2006_07_26a.sql
-- @@mosaic_puzzelsport_2006_07_26b.sql
-- @@mosaic_puzzelsport_2006_07_38a.sql
