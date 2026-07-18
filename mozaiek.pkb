create or replace package body mozaiek
as
  /*
  een vak vertegenwoordigd een statuswaarde en is aanvankelijk onbepaald.
  De aanvankelijke aanwijzingen kunnen aanleiding geven om de 
  statuswaarden langzaamaan te wijzigen naar definitief gevuld
  of definitief ongevuld.

  Een aanwijzingen bevat een voorwaarde met betrekking tot een telling.
  Deze telling is het aantal vakken binnen het blok waarop de aanwijzing
  betrekking heeft waarvan de vakken gekleurd moeten zijn.

  Elk blok wordt gevormd door een vak met haar aangrenzende vakken.

  De eerste te verwerken aanwijzingen zijn die waarin een nul staat.
  Daarna volgen de aanwijzingen die maar 1 oplossing hebben.

  */
  subtype telling_type is simple_integer;
  subtype index_type is pls_integer;
  subtype inkleuring_type  is char(1) not null; -- gevuld 'x', ongevuld '-' of onbepaald ' '

  C_DEBUG          constant boolean:=true;

  C_MAX_ITERATIONS constant telling_type:=500;
  C_INKLEURING_ONBEPAALD  constant inkleuring_type :=' ';
  C_INKLEURING_INGEKLEURD constant inkleuring_type :='X';
  C_INKLEURING_BLANCO     constant inkleuring_type :='-';

  type dimensies_type is
  record
  ( rijen     telling_type default 0
  , kolommen  telling_type default 0
  );

  type ntb_indices_type is table of index_type;

  type vak_type is
  record
  ( inkleuring  inkleuring_type default C_INKLEURING_ONBEPAALD
  , buren       ntb_indices_type
  );

  type ntb_vakken_type is table of vak_type;

  type hash_aanwijzingen_type is table of telling_type index by index_type;

  type puzzel_type is
  record
  ( dimensies           dimensies_type
  , vakken              ntb_vakken_type
  , aanwijzingen        hash_aanwijzingen_type
  );

  procedure print
  ( pi_line in varchar2
  )
  is
  begin
    dbms_output.put_line(pi_line);
  end print;

  procedure debug_message
  ( pi_line in varchar2
  )
  is
  begin
    if C_DEBUG
    then
      print(pi_line);
    end if;  
  end;

  function opgelost
  ( pi_puzzel in puzzel_type
  )
  return puzzel_type
  is
    l_puzzel puzzel_type:=pi_puzzel;
  begin
    null;/*todo*/
    return l_puzzel;
  end opgelost;

  procedure valideer
  ( pi_propositie in boolean
  , pi_melding_als_onwaar in varchar2
  )
  is
  begin
    if not pi_propositie
    then
      dbms_output.put_line ( pi_melding_als_onwaar );
      raise_application_error ( -20000, 'incorrecte invoer, zie voorgaande melding' );
    end if;
  end valideer;

  function als_getal_gelezen
  ( pi_symbool in varchar2
  , pi_melding_als_fout in varchar2 default null
  )
  return telling_type
  is
  begin
    return to_number(pi_symbool);
  exception
    when others
    then
      dbms_output.put_line(pi_melding_als_fout);
      raise;
  end als_getal_gelezen;

  function geindexeerd
  ( pi_puzzel in puzzel_type
  , pi_rij    in telling_type
  , pi_kolom  in telling_type
  ) return telling_type
  is
  begin
    return pi_puzzel.dimensies.kolommen * ( pi_rij - 1 ) + pi_kolom;
  end geindexeerd;

  function puzzel_van_diagram
  ( pi_diagram in diagram
  )
  return puzzel_type
  is
    -- initialiseer nieuwe puzzel op basis van gegeven diagram
    l_puzzel puzzel_type;
    l_aanwijzing_symbool varchar2(1);
    l_aantal_inkleuringen telling_type:=0;
    l_buren  ntb_indices_type;
  begin
    -- initialiseer de vakken
    l_puzzel.dimensies.rijen:=pi_diagram.count;
    l_puzzel.dimensies.kolommen:=length(pi_diagram(1));
    -- initialiseer een lijst met vakken
    l_puzzel.vakken:=ntb_vakken_type();
    -- maak de inhoudelijk nog onbepaalde vakken aan
    l_puzzel.vakken.extend(l_puzzel.dimensies.rijen*l_puzzel.dimensies.kolommen);
    for i in 1..l_puzzel.dimensies.rijen
    -- voor elke regel i
    loop
      valideer
      ( l_puzzel.dimensies.kolommen = length(pi_diagram(i))
      , apex_string.format
        ( 'regel %0 heeft afwijkend aantal kolommen'
        , i
        )
      );
      for j in 1..l_puzzel.dimensies.rijen
      -- voor elke kolom j
      loop
        -- leg een lijst van buren vast
        l_buren:=ntb_indices_type();
        for dx in -1 .. 1 loop
          for dy in -1 .. 1 loop
            if not ( dx = 0 and dy = 0 )
            and ( i+dx between 1 and l_puzzel.dimensies.rijen)
            and ( j+dy between 1 and l_puzzel.dimensies.kolommen)
            then
              l_buren.extend();
              l_buren(l_buren.count):=geindexeerd(l_puzzel,i+dx,j+dy);
              debug_message
              ( apex_string.format
                ( 'buur van (%0,%1) is (%2,%3) met index %4'
                , i
                , j
                , i+dx
                , j+dy
                , geindexeerd(l_puzzel,i+dx,j+dy)
                )
              );
            end if;
          end loop;
        end loop;
        l_puzzel.vakken(geindexeerd(l_puzzel,i,j)).buren:=l_buren;
        debug_message
        ( apex_string.format
          ( 'vak (%0,%1) heeft %2 buren'
          , i
          , j
          , l_puzzel.vakken(geindexeerd(l_puzzel,i,j)).buren.count
          )
        );
        -- stel de mogelijke aanwijzing vast
        l_aanwijzing_symbool:=trim(substr(pi_diagram(i),j,1));
        if l_aanwijzing_symbool is not null
        then
          l_aantal_inkleuringen:=
            als_getal_gelezen
            ( l_aanwijzing_symbool
            , apex_string.format
              ( 'teken "%0" op rij %1 en positie %2 is geen geldig aantal.'
              , l_aanwijzing_symbool
              , i
              , j
              )
            );
          l_puzzel.aanwijzingen(geindexeerd(l_puzzel,i,j)):=l_aantal_inkleuringen;
          debug_message
          ( apex_string.format
            ( 'regel %0 kolom %1 heeft aanwijzing %2'
            , i
            , j
            , l_aantal_inkleuringen
            )
          );
        end if;
      end loop;
    end loop;
    return l_puzzel;
  end puzzel_van_diagram;

  function opgelost
  ( pi_diagram in diagram
  )
  return puzzel_type
  is
    -- geef opgeloste puzzel van geconverteerd diagram
  begin
    return opgelost(puzzel_van_diagram(pi_diagram));
  end opgelost;

  procedure afdrukken
  ( pi_puzzel in puzzel_type
  )
  is
  begin
    dbms_output.put_line(apex_string.format('aantal rijen     : %0', pi_puzzel.dimensies.rijen));
    dbms_output.put_line(apex_string.format('aantal kolommen  : %0', pi_puzzel.dimensies.kolommen));

    dbms_output.put_line(apex_string.format('aantal vakken    : %0', pi_puzzel.vakken.count));
  end afdrukken;

  /****************************************************************************
   * package global program units
   ***************************************************************************/
  procedure oplossen
  ( pi_diagram in diagram
  )
  is
  begin
    afdrukken(opgelost(pi_diagram));
  end oplossen;

end mozaiek;
/
