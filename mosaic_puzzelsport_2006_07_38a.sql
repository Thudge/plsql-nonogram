set feedback off serveroutput on
spool output\mosaic_puzzelsport_2006_07_38a.html
begin
  -- Puzzel Sport 2006 Japanse Puzzel Mix, Mozaïek pagina 38 a
  -- PS3100207
  mozaiek.oplossen
  ( mozaiek.diagram
    ( '  3 3     3333 '
    , '3     4  5    4'
    , ' 33  4 555 334 '
    , '1 33    5 43   '
    , '  34 4 1 3 0 0 '
    , '  223 20 3     '
    , ' 3  33    55   '
    , ' 2  4 0  4  86 '
    , '  46    3 6  85'
    , ' 4 88   4 78 86'
    , '  68  5 47    5'
    , '4     6  68 75 '
    , ' 7 8  5   565  '
    , ' 68 75  0  3   '
    , '   6          0'
    )
  );
end;
/
spool off
set termout on feedback on
host output\mosaic_puzzelsport_2006_07_38a.html
