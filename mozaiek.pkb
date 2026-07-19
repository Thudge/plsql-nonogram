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
  subtype index_type is pls_integer;      -- een index waarde kan 'leeg' ofwel 'null' zijn
  subtype inkleuring_type  is char(1) not null; -- zie C_INKLEURING_* voor mogelijke waarden

  C_DEBUG          constant boolean:=false;

  C_MAX_ITERATIONS constant telling_type:=500;
  C_INKLEURING_ONBEPAALD  constant inkleuring_type :='?';
  C_INKLEURING_INGEKLEURD constant inkleuring_type :='X';
  C_INKLEURING_BLANCO     constant inkleuring_type :=' ';

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

  function geef_blok
  ( pi_puzzel     in puzzel_type
  , pi_vak_index  in index_type
  )
  return ntb_indices_type
  is
    l_vak_indices ntb_indices_type;
  begin
    l_vak_indices:=pi_puzzel.vakken(pi_vak_index).buren;
    l_vak_indices.extend;
    l_vak_indices(l_vak_indices.count):=pi_vak_index;
    return l_vak_indices;
  end geef_blok;

  procedure markeer_blok
  ( pio_puzzel              in out nocopy puzzel_type
  , pi_vak_in_blok_indices  in ntb_indices_type
  , pi_inkleuring           in inkleuring_type
  )
  is
  begin
    for l_vak_in_blok_index in 1..pi_vak_in_blok_indices.count
    loop
      if pio_puzzel.vakken(pi_vak_in_blok_indices(l_vak_in_blok_index)).inkleuring not in (C_INKLEURING_ONBEPAALD, pi_inkleuring)
      then
        debug_message
        ( apex_string.format
          ( 'vak met index %0 wordt ingekleurd met "%1" maar is al "%2", dus overslaan'
          , l_vak_in_blok_index
          , pi_inkleuring
          , pio_puzzel.vakken(pi_vak_in_blok_indices(l_vak_in_blok_index)).inkleuring
          )
        );
      else  
        pio_puzzel.vakken(pi_vak_in_blok_indices(l_vak_in_blok_index)).inkleuring := pi_inkleuring;
      end if;
    end loop;  
  end markeer_blok;

  function to_index_string
  ( pi_puzzel in puzzel_type
  , pi_vak_index index_type
  )
  return varchar2
  is
  begin
    return apex_string.format
    ( '(%0,%1)'
    , trunc((pi_vak_index-1)/pi_puzzel.dimensies.kolommen+1)
    , mod((pi_vak_index-1),pi_puzzel.dimensies.rijen)+1
    );
  end to_index_string;

  function opgelost
  ( pi_puzzel in puzzel_type
  )
  return puzzel_type
  is
    l_puzzel puzzel_type:=pi_puzzel;
    l_vak_index index_type;
    l_vak_index_volgend index_type;
    l_vak_in_blok_indices ntb_indices_type;
    l_inkleuring                    inkleuring_type:=C_INKLEURING_ONBEPAALD;
    l_aantal_inkleuring_blanco      telling_type:= 0;
    l_aantal_inkleuring_ingekleurd  telling_type:= 0;
    l_aantal_inkleuring_onbepaald   telling_type:= 0;
    l_inkleuring_doorgevoerd boolean:=true;
  begin
    while l_puzzel.aanwijzingen.count > 0
    and l_inkleuring_doorgevoerd
    loop
      l_inkleuring_doorgevoerd:=false;
      /* alle aanwijzingen waarbij het aantal ofwel 0 is en alle vakken onbepaald of blanco zijn
         danwel waarbij het aantal blanco vakken + ingekleurde vakken gelijk is
         aan de aanwijzing, kunnen zondermeer verwerkt worden.
      */
      l_vak_index:=l_puzzel.aanwijzingen.first;
      while l_vak_index is not null
      loop
        debug_message
        ( apex_string.format
          ( 'inspectie van aanwijzing %0 bij vak %1'
          , l_puzzel.aanwijzingen(l_vak_index)
          , to_index_string(l_puzzel,l_vak_index)
          )
        );
        -- vind volgende aanwijzing
        l_vak_index_volgend:=l_puzzel.aanwijzingen.next(l_vak_index);
        l_inkleuring:=C_INKLEURING_ONBEPAALD;
        l_aantal_inkleuring_blanco     := 0;
        l_aantal_inkleuring_ingekleurd := 0;
        l_aantal_inkleuring_onbepaald  := 0;
        l_vak_in_blok_indices:=geef_blok(l_puzzel,l_vak_index);
        -- tel de aantallen bij de buren
        for l_vak_in_blok_index in 1..l_vak_in_blok_indices.count
        loop
          debug_message
          ( apex_string.format
            ( 'inspectie: vak %0 heeft inkleuring "%1"'
            , to_index_string(l_puzzel,l_vak_in_blok_indices(l_vak_in_blok_index))
            , l_puzzel.vakken(l_vak_in_blok_indices(l_vak_in_blok_index)).inkleuring
            )
          );
          case l_puzzel.vakken(l_vak_in_blok_indices(l_vak_in_blok_index)).inkleuring
            when C_INKLEURING_BLANCO then l_aantal_inkleuring_blanco := l_aantal_inkleuring_blanco + 1;
            when C_INKLEURING_INGEKLEURD then l_aantal_inkleuring_ingekleurd := l_aantal_inkleuring_ingekleurd + 1;
            when C_INKLEURING_ONBEPAALD then l_aantal_inkleuring_onbepaald := l_aantal_inkleuring_onbepaald + 1;
            else
              raise_application_error ( -20000, 'ongeldige inkleuring.');
          end case;  
          debug_message
          ( apex_string.format
            ( 'aantallen: onbepaald = %0, blanco = %1, ingekleurd = %2'
            , l_aantal_inkleuring_onbepaald
            , l_aantal_inkleuring_blanco
            , l_aantal_inkleuring_ingekleurd
            )
          );
        end loop;
        -- de uiteindelijke logica
        -- bepaal of er van een definitieve inkleuring sprake kan zijn
        case
          when l_puzzel.aanwijzingen(l_vak_index) = l_aantal_inkleuring_onbepaald + l_aantal_inkleuring_ingekleurd
            then
              --onbepaalde vakken dienen ingekleurd te zijn
              l_inkleuring:=C_INKLEURING_INGEKLEURD;
          when l_puzzel.aanwijzingen(l_vak_index) = l_aantal_inkleuring_ingekleurd
            then
              --onbepaalde vakken dienen blanco te zijn
              l_inkleuring:=C_INKLEURING_BLANCO;
          else
            debug_message
            ( apex_string.format
              ( '(nu nog)overslaan aanwijzing %0 op vak %1'
              , l_puzzel.aanwijzingen(l_vak_index)
              , l_vak_index
              )
            );
        end case;
        if l_inkleuring!=C_INKLEURING_ONBEPAALD
        then
          print
          ( apex_string.format
            ( 'inkleuring met "%0" op blok %1, aanwijzing is %2'
            , l_inkleuring
            , to_index_string(pi_puzzel,l_vak_index)
            , l_puzzel.aanwijzingen(l_vak_index)
            )
          );
          markeer_blok
          ( l_puzzel
          , l_vak_in_blok_indices
          , l_inkleuring
          );
          --verwijder deze aanwijzing
          l_puzzel.aanwijzingen.delete(l_vak_index);
          l_inkleuring_doorgevoerd:=true;
        end if;  
        -- vind volgende aanwijzing
        l_vak_index:=l_vak_index_volgend;
      end loop; 
    end loop;
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
        l_puzzel.vakken(geindexeerd(l_puzzel,i,j)).inkleuring:=C_INKLEURING_ONBEPAALD;
        debug_message
        ( apex_string.format
          ( 'vak (%0,%1) heeft inkleuring "%2"'
          , i
          , j
          , l_puzzel.vakken(geindexeerd(l_puzzel,i,j)).inkleuring
          )
        );
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
    l_rij varchar2(100);
    l_vak_index index_type;
    l_inkleuring inkleuring_type:=C_INKLEURING_ONBEPAALD;
    l_aanwijzing_c varchar2(1);

  begin
    dbms_output.put_line(apex_string.format('aantal rijen         : %0', pi_puzzel.dimensies.rijen));
    dbms_output.put_line(apex_string.format('aantal kolommen      : %0', pi_puzzel.dimensies.kolommen));

    dbms_output.put_line(apex_string.format('aantal vakken        : %0', pi_puzzel.vakken.count));
    dbms_output.put_line(apex_string.format('aantal aanwijzingen  : %0', pi_puzzel.aanwijzingen.count));

    for i in 1..pi_puzzel.dimensies.rijen loop
      l_rij:=null;
      for j in 1..pi_puzzel.dimensies.kolommen loop
        l_vak_index:=geindexeerd(pi_puzzel,i,j);
        l_inkleuring:=pi_puzzel.vakken(l_vak_index).inkleuring;
        l_aanwijzing_c:=' ';
        if pi_puzzel.aanwijzingen.exists(l_vak_index)
        then
          l_aanwijzing_c:=to_char(pi_puzzel.aanwijzingen(l_vak_index));
        end if;
        if pi_puzzel.aanwijzingen.count>0
        then
          l_rij:=l_rij||apex_string.format('(%0)[%1]',l_aanwijzing_c,l_inkleuring);
        else
          l_rij:=l_rij||apex_string.format('%0',l_inkleuring);
        end if;
      end loop;
      print(l_rij);
    end loop;  

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
