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
  subtype inkleuring_type  is varchar2(1) not null; -- zie C_INKLEURING_* voor mogelijke waarden

  C_DEBUG          constant boolean:=false;

  C_MAX_ITERATIONS constant telling_type:=500;
  C_INKLEURING_ONBEPAALD  constant inkleuring_type :='?';
  C_INKLEURING_INGEKLEURD constant inkleuring_type :='X';
  C_INKLEURING_BLANCO     constant inkleuring_type :=' ';

  g_recursief_level pls_integer:=0;

  type dimensies_type is
  record
  ( rijen     telling_type default 0
  , kolommen  telling_type default 0
  );

  type ntb_indices_type is table of index_type;
  type ntb_ntb_indices_type is table of ntb_indices_type;

  type hash_indices_type is table of index_type index by index_type;

  type vak_type is
  record
  ( inkleuring  inkleuring_type default C_INKLEURING_ONBEPAALD
  , buren       ntb_indices_type
  );

  type ntb_vakken_type is table of vak_type;

  type onderverdeeld_blok_type is record
  ( min_ingekleurd        telling_type default 0
  , max_ingekleurd        telling_type default 0
  , onbepaalde_vakken hash_indices_type
  );

  type onderverdeling_type is table of onderverdeeld_blok_type;

  type inkleuring_tellingen_type is table of pls_integer index by inkleuring_type;

  type blok_telling_type is record
  ( aanwijzing                   telling_type default 0
  , onderverdeling               onderverdeling_type default onderverdeling_type()
  , inkleuring_tellingen         inkleuring_tellingen_type := inkleuring_tellingen_type()
  );

  type hash_blok_tellingen_type is table of blok_telling_type index by index_type;

  type afvinklijst is table of pls_integer index by varchar2(200);

  type puzzel_type is
  record
  ( dimensies           dimensies_type
  , vakken              ntb_vakken_type
  , blok_tellingen      hash_blok_tellingen_type
  , blok_tellingen_orig hash_blok_tellingen_type
  , vak_to_blok_tellingen ntb_ntb_indices_type
  , start_moment        timestamp default systimestamp
  , oplostijd           interval day to second
  , voltooide_vergelijkingen afvinklijst
  );

  procedure print
  ( pi_line in varchar2
  , inspring_niveau in telling_type default 0
  )
  is
  begin
    dbms_output.put_line (lpad(' ',inspring_niveau,' ')||pi_line);
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

  function geindexeerd
  ( pi_puzzel in puzzel_type
  , pi_rij    in telling_type
  , pi_kolom  in telling_type
  ) return telling_type
  is
  begin
    return pi_puzzel.dimensies.kolommen * ( pi_rij - 1 ) + pi_kolom;
  end geindexeerd;

  function to_index_string
  ( pi_puzzel in puzzel_type
  , pi_vak_index index_type
  )
  return varchar2
  is
  begin
    return apex_string.format
    ( '(%0,%1)'
    , trunc((pi_vak_index-1)/pi_puzzel.dimensies.kolommen)+1
    , mod(pi_vak_index-1,pi_puzzel.dimensies.kolommen)+1
    );
  end to_index_string;

  function to_index_string
  ( pi_puzzel in puzzel_type
  , pi_hash_indices in hash_indices_type
  )
  return varchar2
  is
    l_index_string varchar2(200);
    t telling_type:=0;
  begin
    for v in indices of pi_hash_indices
    loop
      l_index_string:=l_index_string||to_index_string(pi_puzzel,v);
    end loop;
    return apex_string.format('[%s]', l_index_string);
  end to_index_string;

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

  procedure valideer
  ( pi_puzzel in puzzel_type
  , pi_vak_index in index_type
  , pi_inkleuring in inkleuring_type
  )
  is
  begin
    null;
    case pi_inkleuring
      when c_inkleuring_ingekleurd
      then
        if pi_puzzel.blok_tellingen(pi_vak_index).inkleuring_tellingen(pi_inkleuring)>pi_puzzel.blok_tellingen(pi_vak_index).aanwijzing
        then
          raise_application_error
          ( -20000
          , apex_string.format
            ( 'Teveel ingekleurde vakken (%s) op vak %s, aantal verwacht: %s<br/>'
            , pi_puzzel.blok_tellingen(pi_vak_index).inkleuring_tellingen(pi_inkleuring)
            , to_index_string(pi_puzzel, pi_vak_index)
            , pi_puzzel.blok_tellingen(pi_vak_index).aanwijzing
            )
          );
        end if;  
      else
        if pi_puzzel.vakken(pi_vak_index).buren.count + 1 - pi_puzzel.blok_tellingen(pi_vak_index).inkleuring_tellingen(pi_inkleuring)<pi_puzzel.blok_tellingen(pi_vak_index).aanwijzing
        then
          raise_application_error
          ( -20000
          , apex_string.format
            ( 'Te weinig resterende (%s) in te kleuren vakken op vak %s, aantal verwacht: %s<br/>'
            , pi_puzzel.vakken(pi_vak_index).buren.count + 1 - pi_puzzel.blok_tellingen(pi_vak_index).inkleuring_tellingen(pi_inkleuring)
            , to_index_string(pi_puzzel, pi_vak_index)
            , pi_puzzel.blok_tellingen(pi_vak_index).aanwijzing
            )
          );
        end if;
    end case;
  end valideer;

  procedure valideer
  ( pi_puzzel in puzzel_type
  )
  is
    PRAGMA DEPRECATE (valideer, 'mozaiek.valideer is deprecated, use something else instead.');
    l_orig_aanwijzing telling_type:=0;
    l_huidig_ingekleurd telling_type:=0;
  begin
    --controleer of nog steeds aan alle aanwijzingen is voldaan
    for i_vak in indices of pi_puzzel.blok_tellingen_orig
    loop
      l_orig_aanwijzing := pi_puzzel.blok_tellingen_orig(i_vak).aanwijzing;
      l_huidig_ingekleurd:=0;
      for v in values of geef_blok ( pi_puzzel, i_vak )
      loop
        if pi_puzzel.vakken(v).inkleuring = C_INKLEURING_INGEKLEURD
        then
          l_huidig_ingekleurd:=l_huidig_ingekleurd+1;
        end if;
      end loop;
      if l_huidig_ingekleurd > l_orig_aanwijzing
      then
        raise_application_error
        ( -20000
        , ( apex_string.format
            ( '#ERROR# Op blok %s, worden %s inkleuringen verwacht maar %s geteld.'
            , to_index_string ( pi_puzzel, i_vak)
            , l_orig_aanwijzing
            , l_huidig_ingekleurd
            )
          )
        );
      end if;
    end loop;
  end valideer;

  procedure markeer_onderverdeling
  ( pio_puzzel              in out nocopy puzzel_type
  , pi_vak_index            in telling_type
  , pi_inkleuring           in inkleuring_type
  )
  is
  begin
    debug_message
    ( apex_string.format
      ( 'markeer_onderverdeling: vak %s gaat van "%s" naar "%s"<br/>'
      , to_index_string(pio_puzzel,pi_vak_index)
      , pio_puzzel.vakken(pi_vak_index).inkleuring
      , pi_inkleuring
      )
    );
    if pio_puzzel.vakken(pi_vak_index).inkleuring != C_INKLEURING_ONBEPAALD
    then
      raise_application_error(-20000,'Dit vak is al ingekleurd met '||pi_inkleuring);
    end if;

    pio_puzzel.vakken(pi_vak_index).inkleuring := pi_inkleuring;

    for i_blok_telling in values of pio_puzzel.vak_to_blok_tellingen(pi_vak_index)
    loop
      debug_message
      ( apex_string.format
        ( 'markeer_onderverdeling: dit vak wordt geteld in blok %s<br/>'
        , to_index_string(pio_puzzel,i_blok_telling)
        )
      );

      if pio_puzzel.blok_tellingen.exists(i_blok_telling)
      then
        debug_message
        ( apex_string.format
          ( 'markeer_onderverdeling: dit blok is er nog<br/>'
          )
        );

        -- administreer tellingen op deze aanwijzing
        pio_puzzel.blok_tellingen(i_blok_telling).inkleuring_tellingen(pi_inkleuring):=
          pio_puzzel.blok_tellingen(i_blok_telling).inkleuring_tellingen(pi_inkleuring)+1;

        valideer
        ( pio_puzzel
        , i_blok_telling
        , pi_inkleuring
        );

        -- als vak in onderverdeling voorkomt
        for i_onderverdeling in indices of pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling
        loop
          debug_message
          ( apex_string.format
            ( 'markeer_onderverdeling: onderverdeling %s<br/>'
            , i_onderverdeling
            )
          );
          if pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).onbepaalde_vakken.exists(pi_vak_index)
          then
            debug_message
            ( apex_string.format
              ( 'markeer_onderverdeling: vak %s komt voor in onderverdeling %s met daarin %s vakken<br/>'
              , to_index_string(pio_puzzel,pi_vak_index)
              , i_onderverdeling
              , pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).onbepaalde_vakken.count
              )
            );
            if pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).onbepaalde_vakken.count > 1
            then
              debug_message
              ( apex_string.format
                ( 'markeer_onderverdeling PRE : vak %s in blok %s\ %s:%s[%s,%s]<br/>'
                , to_index_string(pio_puzzel,pi_vak_index)
                , to_index_string(pio_puzzel,i_blok_telling)
                , i_onderverdeling
                , pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).onbepaalde_vakken.count
                , pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).min_ingekleurd
                , pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).max_ingekleurd
                )
              );
              pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).onbepaalde_vakken.delete(pi_vak_index);
              if pi_inkleuring = C_INKLEURING_INGEKLEURD
              then
                pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).min_ingekleurd:=
                  greatest
                  ( pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).min_ingekleurd - 1
                  , 0
                  );
                pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).max_ingekleurd:=
                  greatest
                  ( pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).max_ingekleurd - 1
                  , 0
                  );
              else
                -- minimum kan niet hoger zijn #onbepaalde vlakken
                pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).min_ingekleurd:=
                  least
                  ( pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).min_ingekleurd
                  , pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).onbepaalde_vakken.count
                  );
                -- maximum kan niet hoger zijn #onbepaalde vlakken
                pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).max_ingekleurd:=
                  least
                  ( pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).max_ingekleurd
                  , pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).onbepaalde_vakken.count
                  );
                -- blanco geplaatst dus minimum van evt. (enig mogelijke) andere segment 1 verhogen
              end if;
              debug_message
              ( apex_string.format
                ( 'markeer_onderverdeling POST: vak %s in blok %s\ %s:%s[%s,%s]<br/>'
                , to_index_string(pio_puzzel,pi_vak_index)
                , to_index_string(pio_puzzel,i_blok_telling)
                , i_onderverdeling
                , pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).onbepaalde_vakken.count
                , pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).min_ingekleurd
                , pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).max_ingekleurd
                )
              );
            else
              pio_puzzel.blok_tellingen(i_blok_telling).onderverdeling.delete(i_onderverdeling);
            end if;
          end if;
        end loop;
      else
        debug_message
        ( apex_string.format
          ( 'dit blok is er al niet meer<br/>'
          )
        );
      end if;  
    end loop;
  end markeer_onderverdeling;

  procedure verfijn_op_onderverdelingen
  ( pio_puzzel in out nocopy puzzel_type
  )
  is
    l_vak_index_main          index_type;
    l_vak_index_buur          index_type;
    l_main_old  onderverdeling_type;
    l_main      onderverdeling_type;
    l_buur      onderverdeling_type;
    l_overlap   onderverdeeld_blok_type;
    l_succesvolle_onderverdeling boolean;
    l_uid_vergelijking varchar2(200);
  begin
    <<main>>
    for l_vak_index_main in indices of pio_puzzel.blok_tellingen
    loop
      l_main_old:=pio_puzzel.blok_tellingen(l_vak_index_main).onderverdeling;
      if l_main_old.count > 1
      then
        debug_message
        ( apex_string.format
          ( 'vak %s bevat reeds meer onderverdeelde segmenten (%s)<br/>'
          , to_index_string ( pio_puzzel, l_vak_index_main )
          , l_main_old.count
          )
        );
        continue;
      end if;  

      l_main:=l_main_old;
      l_succesvolle_onderverdeling:=false;
      <<buur>>
      for l_vak_index_buur in values of pio_puzzel.vakken(l_vak_index_main).buren
      loop
        -- mits buur een aanwijzing heeft
        if not pio_puzzel.blok_tellingen.exists(l_vak_index_buur)
        then
          continue;
        end if;  
        l_buur:=pio_puzzel.blok_tellingen(l_vak_index_buur).onderverdeling;
        -- vergelijk hoofdaanwijzing met buuraanwijzing
        <<main_segment>>
        for i_main in indices of l_main_old
        loop
          -- mits main segment niet reeds opgelost is
          if l_main_old(i_main).onbepaalde_vakken.count = l_main_old(i_main).min_ingekleurd
             or
             l_main_old(i_main).max_ingekleurd = 0
          then
            debug_message
            ( apex_string.format
              ( 'hoofd vak %s \ %s:%s[%s,%s] kan reeds worden ingekleurd<br/>'
              , to_index_string ( pio_puzzel, l_vak_index_main )
              , i_main
              , l_main_old(i_main).onbepaalde_vakken.count
              , l_main_old(i_main).min_ingekleurd
              , l_main_old(i_main).max_ingekleurd
              ) 
            );
            continue;
          end if;
          <<buur_segment>>
          for i_buur in indices of l_buur
          loop
            -- mits buur segment niet reeds opgelost is
            if l_buur(i_buur).onbepaalde_vakken.count = l_buur(i_buur).min_ingekleurd
               or
               l_buur(i_buur).max_ingekleurd = 0
            then
              debug_message
              ( apex_string.format
                ( 'buur vak %s \ %s:%s[%s,%s] kan reeds worden ingekleurd<br/>'
                , to_index_string ( pio_puzzel, l_vak_index_buur )
                , i_buur
                , l_buur(i_buur).onbepaalde_vakken.count
                , l_buur(i_buur).min_ingekleurd
                , l_buur(i_buur).max_ingekleurd
                ) 
              );
              continue;
            end if;  
            l_main:=l_main_old;
            debug_message
            ( apex_string.format
              ( 'verfijn_op_onderverdelingen: vergelijk nu hoofd vak %s \ %s:%s[%s,%s] met buur vak %s \ %s:%s[%s,%s]<br/>'
              , to_index_string ( pio_puzzel, l_vak_index_main )
              , i_main
              , l_main_old(i_main).onbepaalde_vakken.count
              , l_main_old(i_main).min_ingekleurd
              , l_main_old(i_main).max_ingekleurd
              , to_index_string ( pio_puzzel, l_vak_index_buur )
              , i_buur
              , l_buur(i_buur).onbepaalde_vakken.count
              , l_buur(i_buur).min_ingekleurd
              , l_buur(i_buur).max_ingekleurd
              ) 
            );
            l_uid_vergelijking:=
              ( apex_string.format
                ( 'UID:%s:<%s,%s>[%s] === %s:<%s,%s>[%s]<br/>'
                , to_index_string ( pio_puzzel, l_vak_index_main )
                , l_main_old(i_main).min_ingekleurd
                , l_main_old(i_main).max_ingekleurd
                , to_index_string( pio_puzzel, l_main_old(i_main).onbepaalde_vakken)
                , to_index_string ( pio_puzzel, l_vak_index_buur )
                , l_buur(i_buur).min_ingekleurd
                , l_buur(i_buur).max_ingekleurd
                , to_index_string( pio_puzzel, l_buur(i_buur).onbepaalde_vakken)
                ) 
              );
            if pio_puzzel.voltooide_vergelijkingen.exists(l_uid_vergelijking)
            then
              debug_message ( 'Reeds voltooide vergelijking.<br/>'); 
              continue;
            end if;
            pio_puzzel.voltooide_vergelijkingen(l_uid_vergelijking):=1;
            -- bepaal de set van overlappende vakken
            -- haal deze over naar een nieuwe set binnen de onderverdeling!
            l_overlap:=null;
            for i_vak_index in indices of l_main(i_main).onbepaalde_vakken
            loop
              if l_buur(i_buur).onbepaalde_vakken.exists(i_vak_index)
              then
                l_overlap.onbepaalde_vakken(i_vak_index):=1;
                l_main(i_main).onbepaalde_vakken.delete(i_vak_index);
              end if;
            end loop;

            -- als niets overlapt, kijk dan naar volgende buur segment
            if l_overlap.onbepaalde_vakken.count = 0
            then
              debug_message
              ( apex_string.format
                ( 'Overslaan: hierin geen overlap<br/>'
                ) 
              );
              continue;
            end if;

            -- als ALLES overlapt met bestaande hoofdvak, kijk dan naar volgende buur segment
            if l_overlap.onbepaalde_vakken.count = l_main_old(i_main).onbepaalde_vakken.count
            then
              debug_message
              ( apex_string.format
                ( 'Overslaan: overlap is gelijk aan hoofdvak<br/>'
                ) 
              );
              continue;
            end if;  

            -- overlap
            l_overlap.min_ingekleurd:=
              greatest
              ( 0
              , l_main(i_main).max_ingekleurd - ( l_main_old(i_main).onbepaalde_vakken.count - l_overlap.onbepaalde_vakken.count )
              , l_buur(i_buur).max_ingekleurd - ( l_buur(i_buur).onbepaalde_vakken.count - l_overlap.onbepaalde_vakken.count )
              );
            l_overlap.max_ingekleurd:=
              least
              ( l_overlap.onbepaalde_vakken.count
              , l_main(i_main).max_ingekleurd
              , l_buur(i_buur).max_ingekleurd
              );
            -- segment in main dat overblijft
            l_main(i_main).min_ingekleurd:=
              greatest ( 0 , l_main(i_main).min_ingekleurd - l_overlap.max_ingekleurd );
            l_main(i_main).max_ingekleurd:=
              least ( l_main(i_main).onbepaalde_vakken.count, l_main(i_main).max_ingekleurd - l_overlap.min_ingekleurd );

            debug_message
            ( apex_string.format
              ( 'Verfijning: oude min,max [%s/%s], nieuwe [%s,%s] en [%s,%s]<br/>'
              , l_main_old(i_main).min_ingekleurd
              , l_main_old(i_main).max_ingekleurd
              , l_main(i_main).min_ingekleurd
              , l_main(i_main).max_ingekleurd
              , l_overlap.min_ingekleurd
              , l_overlap.max_ingekleurd
              ) 
            );
            l_main.extend();
            l_main(l_main.last):=l_overlap;
            --beoordeel de nieuwe onderverdeling
            for n in indices of l_main
            loop
              continue when n not in ( i_main, l_main.last);
              l_succesvolle_onderverdeling := 
                l_succesvolle_onderverdeling
                or 
                l_main(n).min_ingekleurd = l_main(n).onbepaalde_vakken.count
                or
                l_main(n).max_ingekleurd = 0;
              debug_message
              ( apex_string.format
                ( 'Beoordeling onderverdeling segment %s:%s[%s,%s] : %s op vakken %s<br/>'
                , n
                , l_main(n).onbepaalde_vakken.count
                , l_main(n).min_ingekleurd
                , l_main(n).max_ingekleurd
                , case when l_succesvolle_onderverdeling then 'SUCCES' else 'FAIL' end
                , to_index_string(pio_puzzel,l_main(n).onbepaalde_vakken)
                ) 
              );
              if l_main(n).min_ingekleurd < 0
              then
                raise_application_error(-20000, 'min moet groter dan 0 zijn<br/>');
              end if;  
              if l_main(n).max_ingekleurd < 0
              then
                raise_application_error(-20000, 'max moet groter dan 0 zijn<br/>');
              end if;  
              if l_main(n).min_ingekleurd > l_main(n).max_ingekleurd
              then
                raise_application_error(-20000, 'min moet niet groter dan max zijn<br/>');
              end if;  
              if l_main(n).max_ingekleurd > l_main(n).onbepaalde_vakken.count
              then
                raise_application_error(-20000, 'max moet niet groter dan aantal onbepaald zijn<br/>');
              end if;  
            end loop;
            -- stel de nieuwe onderverdeling in
            if l_succesvolle_onderverdeling
            then
              pio_puzzel.blok_tellingen(l_vak_index_main).onderverdeling:=l_main;
              exit main;
            end if;
          end loop buur_segment;
        end loop main_segment;
      end loop buur;
    end loop main;
  end verfijn_op_onderverdelingen;

  function opgelost
  ( pi_puzzel in puzzel_type
  )
  return puzzel_type
  is
    l_puzzel      puzzel_type:=pi_puzzel;
    l_puzzel_orig constant puzzel_type:=pi_puzzel;
    l_vak_index index_type;
    l_vak_index_volgend index_type;
    l_inkleuring                    inkleuring_type:=C_INKLEURING_ONBEPAALD;
    l_inkleuring_doorgevoerd boolean:=true;
    l_onderverdeling                onderverdeling_type;
  begin
    <<opgelost_main>>
    while l_puzzel.blok_tellingen.count > 0
    and l_inkleuring_doorgevoerd
    loop
      l_inkleuring_doorgevoerd:=false;
      l_vak_index:=l_puzzel.blok_tellingen.first;
      while l_vak_index is not null
      loop
        -- vind alvast volgende aanwijzing, want huidige wordt misschien onderstaand verwijderd
        l_vak_index_volgend:=l_puzzel.blok_tellingen.next(l_vak_index);
        l_inkleuring:=C_INKLEURING_ONBEPAALD;
        -- de uiteindelijke logica
        l_onderverdeling:=l_puzzel.blok_tellingen(l_vak_index).onderverdeling;
        for i_onderverdeling in indices of l_onderverdeling
        loop
          -- voor elke onderverdeling
          case
            -- bepaal of er van een definitieve inkleuring sprake kan zijn
            when l_onderverdeling(i_onderverdeling).max_ingekleurd = 0
              then
                --onbepaalde vakken dienen blanco te zijn
                debug_message
                ( apex_string.format
                  ( q'{strategie 'blanco': inkleuring met "%s" op blok %s, aanwijzing is %s<br/>}'
                  , C_INKLEURING_BLANCO
                  , to_index_string(l_puzzel,l_vak_index)
                  , l_puzzel.blok_tellingen(l_vak_index).aanwijzing
                  )
                );
                for i_vak in indices of l_puzzel.blok_tellingen(l_vak_index).onderverdeling(i_onderverdeling).onbepaalde_vakken
                loop
                  markeer_onderverdeling
                  ( l_puzzel
                  , i_vak
                  , C_INKLEURING_BLANCO
                  );
                end loop;  
                --verwijder deze onderverdeling
                l_puzzel.blok_tellingen(l_vak_index).onderverdeling.delete(i_onderverdeling);
                l_inkleuring_doorgevoerd:=true;
            -- bepaal of er van een definitieve blanco inkleuring sprake kan zijn
            when l_onderverdeling(i_onderverdeling).min_ingekleurd = l_onderverdeling(i_onderverdeling).onbepaalde_vakken.count
              then
                --onbepaalde vakken dienen ingekleurd te zijn
                debug_message
                ( apex_string.format
                  ( q'{strategie 'ingekleurd': inkleuring met "%s" op blok %s, aanwijzing is %s<br/>}'
                  , C_INKLEURING_INGEKLEURD
                  , to_index_string(l_puzzel,l_vak_index)
                  , l_puzzel.blok_tellingen(l_vak_index).aanwijzing
                  )
                );
                for i_vak in indices of l_puzzel.blok_tellingen(l_vak_index).onderverdeling(i_onderverdeling).onbepaalde_vakken
                loop
                  markeer_onderverdeling
                  ( l_puzzel
                  , i_vak
                  , C_INKLEURING_INGEKLEURD
                  );
                end loop;  
                --verwijder deze onderverdeling
                l_puzzel.blok_tellingen(l_vak_index).onderverdeling.delete(i_onderverdeling);
                l_inkleuring_doorgevoerd:=true;
            else
              debug_message
              ( apex_string.format
                ( '(nu nog)overslaan aanwijzing %s op vak %s<br/>'
                , l_puzzel.blok_tellingen(l_vak_index).aanwijzing
                , to_index_string(l_puzzel,l_vak_index)
                )
              );
          end case;
        end loop; -- voor elke onderverdeling
        -- geen onderverdelingen meer ? verwijder de bloktelling
        if l_puzzel.blok_tellingen(l_vak_index).onderverdeling.count = 0
        then
          l_puzzel.blok_tellingen.delete(l_vak_index);
        end if;
        -- vind volgende aanwijzing
        l_vak_index:=l_vak_index_volgend;
      end loop; 
      if l_inkleuring_doorgevoerd
      then
        verfijn_op_onderverdelingen(l_puzzel);
      elsif l_puzzel.blok_tellingen.count > 0
      then
        -- make a guess
        declare
          l_aantal_onbepaald pls_integer;
          l_min_aantal_onbepaald pls_integer:=10;
          l_vak_probeer index_type:=l_puzzel.blok_tellingen.first;
          l_probeer_vakken ntb_indices_type:=ntb_indices_type();
        begin
          -- op een resterend blok met zo min mogelijk overblijvende vakken
          -- wordt één voor één een vak geprobeerd in te kleuren
          for i_vak in indices of l_puzzel.blok_tellingen
          loop
            l_aantal_onbepaald:=0;
            for j in indices of l_puzzel.blok_tellingen(i_vak).onderverdeling
            loop
              l_aantal_onbepaald:=l_aantal_onbepaald+l_puzzel.blok_tellingen(i_vak).onderverdeling(j).onbepaalde_vakken.count;
            end loop;
            if l_aantal_onbepaald < l_min_aantal_onbepaald
            then
              l_min_aantal_onbepaald := l_aantal_onbepaald;
              l_vak_probeer := i_vak;
            end if;  
          end loop;
          debug_message
          ( apex_string.format
            ( 'probeer alle %s vakken rond aanwijzing op %s in te kleuren<br/>'
            , l_min_aantal_onbepaald
            , to_index_string(l_puzzel, l_vak_probeer)
            )
          );


          for i_onderverdeling in indices of l_puzzel.blok_tellingen(l_vak_probeer).onderverdeling
          loop
            for i_vak in indices of l_puzzel.blok_tellingen(l_vak_probeer).onderverdeling(i_onderverdeling).onbepaalde_vakken
            loop
              l_probeer_vakken.extend();
              l_probeer_vakken(l_probeer_vakken.last):=i_vak;
              debug_message
              ( apex_string.format
                ( 'namelijk vak %s<br/>'
                , to_index_string(l_puzzel, i_vak)
                )
              );
            end loop;  
          end loop;

          for i_probeer_vak in values of l_probeer_vakken
          loop
            declare
              l_probeer_puzzel puzzel_type:=l_puzzel;
              l_recursief_level pls_integer:=g_recursief_level;
            begin
              if g_recursief_level > 12
              then
                raise_application_error ( -20000, 'afvangen van te hoog recursief level');
              end if;
              markeer_onderverdeling
              ( l_probeer_puzzel
              , i_probeer_vak
              , c_inkleuring_ingekleurd
              );
              g_recursief_level:=g_recursief_level+1;
              l_probeer_puzzel:=opgelost(l_probeer_puzzel);
              -- als dat goed ging:
              g_recursief_level:=l_recursief_level;
              l_puzzel:=l_probeer_puzzel;
              exit opgelost_main;
            exception
              when others
              then
                g_recursief_level:=l_recursief_level;
                debug_message ( 'Backtracking: naar volgende optie.<br/>' );
            end;
          end loop;
          raise_application_error ( -20000, 'Backtracking: alle opties uitgelopen.');
        end;
      end if;
    end loop opgelost_main;
    l_puzzel.oplostijd:=systimestamp-l_puzzel.start_moment;
    return l_puzzel;
  end opgelost;

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

  procedure maak_onderverdelingen
  ( pio_puzzel in out nocopy puzzel_type
  )
  is
    l_vak_in_blok_indices ntb_indices_type;
    l_onderverdeling_beschrijving varchar2(4000);
  begin
    --default onderverdeling maken voor elk vak met een aanwijzing
    for l_vak_index in indices of pio_puzzel.blok_tellingen
    loop
      l_onderverdeling_beschrijving:=null;
      -- initiëel gaan er minimaal EN maximaal <aanwijzing> gekleurde vakken
      -- in het blok bestaande uit het vak met haar buren
      pio_puzzel.blok_tellingen(l_vak_index).onderverdeling.extend;
      l_vak_in_blok_indices:=geef_blok(pio_puzzel,l_vak_index);
      for t in 1..l_vak_in_blok_indices.count
      loop
        l_onderverdeling_beschrijving:=l_onderverdeling_beschrijving||to_index_string(pio_puzzel,l_vak_in_blok_indices(t));
        pio_puzzel.blok_tellingen(l_vak_index).onderverdeling(1).onbepaalde_vakken(l_vak_in_blok_indices(t)):=1; -- waarde zelf geen betekenis
        pio_puzzel.blok_tellingen(l_vak_index).onderverdeling(1).min_ingekleurd:=pio_puzzel.blok_tellingen(l_vak_index).aanwijzing;
        pio_puzzel.blok_tellingen(l_vak_index).onderverdeling(1).max_ingekleurd:=pio_puzzel.blok_tellingen(l_vak_index).aanwijzing;
      end loop;
      debug_message
      ( apex_string.format
        ( '** vak %s initiële onderverdeling: min %s en max %s van de %s gekleurde vakken in [%s] <br/>'
        , to_index_string ( pio_puzzel, l_vak_index )
        , pio_puzzel.blok_tellingen(l_vak_index).onderverdeling(1).min_ingekleurd
        , pio_puzzel.blok_tellingen(l_vak_index).onderverdeling(1).max_ingekleurd
        , pio_puzzel.blok_tellingen(l_vak_index).onderverdeling(1).onbepaalde_vakken.count
        , l_onderverdeling_beschrijving
        )
      );
    end loop;
  end maak_onderverdelingen;

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
    l_vak_index index_type;
    l_vak_in_blok_indices ntb_indices_type;
    l_buur_vak_index index_type;
    l_blok_telling blok_telling_type;
  begin
    -- initialiseer de vakken
    l_puzzel.dimensies.rijen:=pi_diagram.count;
    l_puzzel.dimensies.kolommen:=length(pi_diagram(1));
    -- initialiseer een lijst met vakken
    l_puzzel.vakken:=ntb_vakken_type();
    -- maak de inhoudelijk nog onbepaalde vakken aan
    l_puzzel.vakken.extend(l_puzzel.dimensies.rijen*l_puzzel.dimensies.kolommen);
    -- initialiseer de 'reverse index' van bij welke blokken elk vak hoort
    l_puzzel.vak_to_blok_tellingen:=ntb_ntb_indices_type();
    -- maak de inhoudelijk nog onbepaalde lijst van blokken aan
    l_puzzel.vak_to_blok_tellingen.extend(l_puzzel.dimensies.rijen*l_puzzel.dimensies.kolommen);

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
      for j in 1..l_puzzel.dimensies.kolommen
      -- voor elke kolom j
      loop
        debug_message
        ( apex_string.format
          ( 'vak (%s,%s), geindexeerd %s heeft inkleuring "%s"<br/>'
          , i
          , j
          , geindexeerd(l_puzzel,i,j)
          , c_inkleuring_onbepaald
          )
        );
        l_puzzel.vakken(geindexeerd(l_puzzel,i,j)).inkleuring:=c_inkleuring_onbepaald;
        l_puzzel.vak_to_blok_tellingen(geindexeerd(l_puzzel,i,j)):=ntb_indices_type();
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
            end if;
          end loop;
        end loop;
        l_puzzel.vakken(geindexeerd(l_puzzel,i,j)).buren:=l_buren;
        /*
        debug_message
        ( apex_string.format
          ( 'vak (%0,%1) heeft %2 buren'
          , i
          , j
          , l_buren.count
          )
        );
        */
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
          l_blok_telling.aanwijzing                   := l_aantal_inkleuringen;
          l_blok_telling.inkleuring_tellingen(c_inkleuring_ingekleurd):=0;
          l_blok_telling.inkleuring_tellingen(c_inkleuring_blanco):=0;
          
          l_puzzel.blok_tellingen(geindexeerd(l_puzzel,i,j)):=l_blok_telling;

          debug_message
          ( apex_string.format
            ( 'vak %s (%s,%s) heeft aanwijzing %s<br/>'
            , geindexeerd(l_puzzel,i,j)
            , i
            , j
            , l_aantal_inkleuringen
            )
          );
        end if;
      end loop;
    end loop;
    -- zorg voor een originele kopie van de bloktellingen
    l_puzzel.blok_tellingen_orig:=l_puzzel.blok_tellingen;
    --
    -- doorloop de vakken om een 'reverse index' op te bouwen bij welke blokken elk
    -- vak hoort
    for l_vak_index in 1..l_puzzel.vakken.count
    loop
      if l_puzzel.blok_tellingen.exists(l_vak_index)
      then
        -- een vak met een aanwijzing behoort tot 'eigen' blok telling
        l_puzzel.vak_to_blok_tellingen(l_vak_index).extend;
        l_puzzel.vak_to_blok_tellingen(l_vak_index)(l_puzzel.vak_to_blok_tellingen(l_vak_index).count):=l_vak_index;
        debug_message
        ( apex_string.format
          ( 'vak %s wordt geteld in eigen blok<br/>'
          , to_index_string(l_puzzel,l_vak_index)
          )
        );
      end if;
      for l_buur_teller in 1..l_puzzel.vakken(l_vak_index).buren.count
      loop
        l_buur_vak_index:=l_puzzel.vakken(l_vak_index).buren(l_buur_teller);
        if l_puzzel.blok_tellingen.exists(l_buur_vak_index)
        then
          debug_message
          ( apex_string.format
            ( 'er zit een aanwijzing op vak %s<br/>'
            , to_index_string(l_puzzel,l_buur_vak_index)
            )
          );
          l_puzzel.vak_to_blok_tellingen(l_vak_index).extend;
          l_puzzel.vak_to_blok_tellingen(l_vak_index)(l_puzzel.vak_to_blok_tellingen(l_vak_index).count):=l_buur_vak_index;
          debug_message
          ( apex_string.format
            ( 'vak %s=%s wordt geteld in blok %s<br/>'
            , l_vak_index
            , to_index_string(l_puzzel,l_vak_index)
            , to_index_string(l_puzzel,l_buur_vak_index)
            )
          );
        end if;
      end loop;
    end loop;

    -- maar voor elk blok met een aanwijzing een eerste onderverdeling
    maak_onderverdelingen(l_puzzel);
    -- verfijn verder mbv de aanwijzingen van naastgelegen vakken met een aanwijzing
    verfijn_op_onderverdelingen(l_puzzel);


    --
    -- specifiek voor de kersen puzzel
/*      markeer_onderverdeling
    ( l_puzzel
    , geindexeerd ( l_puzzel, 4, 10)
    , c_inkleuring_ingekleurd
    );
 */



    return l_puzzel;
  end puzzel_van_diagram;

  procedure htmlprint
  ( pi_puzzel in puzzel_type
  )
  is
    l_cell_size constant natural := 2;
    l_line varchar2(1000);
    l_htmlkleur varchar2(60);
    l_aanwijzing_c varchar2(10);
  begin
    for i_blok_telling in indices of pi_puzzel.blok_tellingen
    loop
      debug_message
      ( apex_string.format
        ( 'htmlprint: telling op vak %s=%s<br/>'
        , i_blok_telling
        , to_index_string(pi_puzzel,i_blok_telling)
        )
      );
      for i_onderverdeling in indices of pi_puzzel.blok_tellingen(i_blok_telling).onderverdeling
      loop
        debug_message
        ( apex_string.format
          ( 'htmlprint: onderverdeling %s min=%s max=%s<br/>'
          , i_onderverdeling
          , pi_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).min_ingekleurd
          , pi_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).max_ingekleurd
          )
        );
        for i_vak in indices of pi_puzzel.blok_tellingen(i_blok_telling).onderverdeling(i_onderverdeling).onbepaalde_vakken
        loop
          debug_message
          ( apex_string.format
            ( 'htmlprint: onderverdeling %s vak %s=%s<br/>'
            , i_onderverdeling
            , i_vak
            , to_index_string(pi_puzzel,i_vak)
            )
          );
        end loop;
      end loop;
    end loop;

    print('<html>');
    print('<head>');
    print('<meta charset="UTF-8">');
    print('<meta http-equiv=Content-Type content="text/html; charset=windows-1252">');
    print('<style>');
    print
    ( apex_string.format
      ( '  table {width: %0; height: %0; table-layout: fixed; border-collapse: separate; }'
      , '800'
      )
    );
    print('  td {color: black; text-align: center; vertical-align: middle;}');
    print('  .ingekleurd {color: white ;background: black; }');
    print('  .onbepaald  {color: white ;background: #529b2a; }');
    print('  .blanco     {background: #ebddad; }');
    print('</style>');
    print('</head>');
    print('<body lang=EN-US>');
    print('<table>');
    for r in 1..pi_puzzel.dimensies.rijen
    loop
      print('<tr>',2);
      for k in 1..pi_puzzel.dimensies.kolommen
      loop
        l_htmlkleur:=
          case pi_puzzel.vakken((geindexeerd(pi_puzzel,r,k))).inkleuring
            when C_INKLEURING_BLANCO then 'blanco'
            when C_INKLEURING_INGEKLEURD then 'ingekleurd'
            when C_INKLEURING_ONBEPAALD then 'onbepaald'
          end;
        begin
          l_aanwijzing_c:=to_char(pi_puzzel.blok_tellingen_orig((geindexeerd(pi_puzzel,r,k))).aanwijzing);
        exception
          when no_data_found
          then
          l_aanwijzing_c:=chr(38)||'nbsp';
        end;
        print
        ( apex_string.format
          ( '<td class="%0">%1</td>'
          , l_htmlkleur
          , l_aanwijzing_c
          )
        , 4  
        );      
      end loop;
      print('</tr>',2);
    end loop;
    print('</table>');
    debug_message(apex_string.format('<p>starttijd: %s</p>',pi_puzzel.start_moment));
    debug_message(apex_string.format('<p>eindtijd : %s</p>',systimestamp));
    print(apex_string.format('<p>beëindigd in %0 milliseconden</p>',round(1000*extract(second from pi_puzzel.oplostijd)),0));
    print(apex_string.format('<p>na %0 unieke aanwijzing vergelijkingen</p>',pi_puzzel.voltooide_vergelijkingen.count  ));
    print('</body>');
    print('</html>');
  end htmlprint;

  procedure afdrukken
  ( pi_puzzel in puzzel_type
  )
  is
  begin
    htmlprint(pi_puzzel);
  end afdrukken;

  function opgelost
  ( pi_diagram in diagram
  )
  return puzzel_type
  is
    -- geef opgeloste puzzel van geconverteerd diagram
    l_puzzel puzzel_type := puzzel_van_diagram(pi_diagram);
  begin
/*     debug_message(apex_string.format('<p>start preparation</p>'));
    afdrukken(l_puzzel);
    debug_message(apex_string.format('<p>end preparation</p>'));
 */    return opgelost(l_puzzel);
  end opgelost;

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
