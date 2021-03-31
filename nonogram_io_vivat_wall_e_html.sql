set termout off feedback off serveroutput on
spool io_vivat_31_1_wall_e.html
begin
  -- IO VIVAT  Jaargang 31 Nummer 1
  jap.oplossen
  ( jap.diagram
    ( jap.dimensie
      ( jap.patroon (2,5)
      , jap.patroon (2,1,1,2)
      , jap.patroon (2,1,1,2,1)
      , jap.patroon (1,2,1,1,2,1)
      , jap.patroon (1,2,1,1,1)
      , jap.patroon (1,1,2,4)
      , jap.patroon (4,2)
      , jap.patroon (2)
      , jap.patroon (2)
      , jap.patroon (12)
      , jap.patroon (2,2)
      , jap.patroon (1,11)
      , jap.patroon (1,5,5)
      , jap.patroon (2,1,1,1,2)
      , jap.patroon (1,5,6)
      , jap.patroon (1,1)
      , jap.patroon (3,2)
      , jap.patroon (2,1,1)
      , jap.patroon (5,1)
      , jap.patroon (2,11)
      , jap.patroon (1,1,1,1)
      , jap.patroon (7,7)
      )
    , jap.dimensie
      ( jap.patroon (3,3)
      , jap.patroon (1,1,3,2,1)
      , jap.patroon (1,1,5,3,1)
      , jap.patroon (1,2,1,2,1,3,1)
      , jap.patroon (1,2,1,1,1,1)
      , jap.patroon (1,1,1,4,2,1)
      , jap.patroon (5,1,2,1,3)
      , jap.patroon (5,2,1,1)
      , jap.patroon (3,5,2,1,3)
      , jap.patroon (1,2,1,4,1,1)
      , jap.patroon (1,1,1,1,1,1)
      , jap.patroon (1,2,1,1,4,1,1)
      , jap.patroon (1,2,1,1,2,1,1,1)
      , jap.patroon (1,1,4,1,1,1,1)
      , jap.patroon (1,1,3,1,3)
      , jap.patroon (2,4,4)
      , jap.patroon (4)
      )  
    )
  );
end;
/
spool off
set termout on feedback on
host "io_vivat_31_1_wall_e.html"
