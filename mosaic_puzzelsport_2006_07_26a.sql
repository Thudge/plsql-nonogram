set feedback off serveroutput on
--spool %tmp%\mosaic_puzzelsport_2006_07_26a.html
begin
  -- Puzzel Sport 2006 Japanse Puzzel Mix, Mozaïek pagina 26 a
  mozaiek.oplossen
  ( mozaiek.diagram
    ( '  542  0  3 6  '
    , '4 5        7 8 '
    , '5   1  5 3    5'
    , '  43 3  7      '
    , '  7521  4 3 5  '
    , ' 4 42  3 1 55 3'
    , '   3 0  00     '
    , '3 2 00    44  5'
    , '   2 3  3  4   '
    , ' 34 556    5 4 '
    , '   566 4 55 3  '
    , '   6  42 3  3  '
    , '0 45  2 2  3 64'
    , ' 0 4    2   7 6'
    , '     33   356  '
    )
  );
end;
/
--spool off
set termout on feedback on
--host %tmp%\"mosaic_puzzelsport_2006_07_26a.html"
