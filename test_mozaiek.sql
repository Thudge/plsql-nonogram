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
@@mosaic_puzzelsport_2006_07_26a.sql
