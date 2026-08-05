set feedback off serveroutput on
spool %tmp%\mosaic_testcase02.html
begin
  -- just 2 hints
  mozaiek.oplossen
  ( mozaiek.diagram
    ( '1 1'
    , ' 4 '
    , '1 1'
    )
  );
end;
/
spool off
set termout on feedback on
host %tmp%\mosaic_testcase02.html
