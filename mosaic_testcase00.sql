set feedback off serveroutput on
spool output\mosaic_testcase00.html
begin
  -- just simple hints
  mozaiek.oplossen
  ( mozaiek.diagram
    ( ' 3 '
    , '   '
    , ' 0 '
    , '   '
    )
  );
end;
/
spool off
set termout on feedback on
-- host output\mosaic_testcase01.html
