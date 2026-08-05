set feedback off serveroutput on
spool %tmp%\mosaic_testcase01.html
begin
  -- just 2 hints
  mozaiek.oplossen
  ( mozaiek.diagram
    ( '    '
    , ' 6  '
    , '  1 '
    , '    '
    )
  );
end;
/
spool off
set termout on feedback on
host %tmp%\mosaic_testcase01.html
