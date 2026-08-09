set feedback off serveroutput on
spool output\mosaic_puzzelsport_2006_07_26b.html
begin
  -- Puzzel Sport 2006 Japanse Puzzel Mix, Mozaïek pagina 26 b
  -- PS3000201
  mozaiek.oplossen
  ( mozaiek.diagram
    ( ' 1   6 6      0'
    , '    66  65 4   '
    , ' 5 7 6     564 '
    , '  64  3  34    '
    , '    3  1 344   '
    , ' 44     3 2 44 '
    , '  4 2  6 3  4  '
    , '0     565  32  '
    , '    445  44 3 0'
    , '  55  4445 6   '
    , '4 87 4  5 7887 '
    , ' 9  63  46 76  '
    , '   96  1  86   '
    , '6  9 3    8  6 '
    , '       1 4     '
    )
  );
end;
/
spool off
set termout on feedback on
host output\mosaic_puzzelsport_2006_07_26b.html
