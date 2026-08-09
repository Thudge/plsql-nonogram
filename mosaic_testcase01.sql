set feedback off serveroutput on
spool output\mosaic_testcase01.html
begin
  -- just 4 hints
  mozaiek.oplossen
  ( mozaiek.diagram
    ( '    '
    , ' 6  '
    , '3 1 '
    , ' 1  '
    )
  );
end;
/
spool off
set termout on feedback on
host output\mosaic_testcase01.html
