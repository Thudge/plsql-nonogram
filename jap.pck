create or replace package jap
as
  type patroon   is table of varchar2(30);
  type dimensie  is table of patroon;
  type diagram   is table of dimensie;
  procedure oplossen
  ( p_diagram in diagram
  );
end jap;
/

create or replace package body jap
as
  /*
  een vak vertegenwoordigd een kleurwaarde en is aanvankelijk leeg.
  vakken zijn gegroepeerd in geordende (van boven naar beneden of
  van links naar rechts) regels. Dit kan dus een
  rij of een kolom voorstellen in het diagram. een 10x15
  diagram heeft 10 rijen, 15 kolommen en 25 regels.
  Bij elk vak kan dan een tweetal geassocieerde regels worden gevonden.

  bij elke regel hoort een kleurpatroon, dat zelf een geordende
  reeks van kleurstrings is.

  Als voorbeeld een rij waarin vijf rode vakjes worden gevolgd
  door vier blauwe.
  De bij invoer opgegeven reeks ('R5','B4') wordt intern vertaald
  naar de lijst ('RRRRR','BBBB').

  */
  type array is table of natural;

  subtype kleur_type  is char(1);
  subtype kleurstring is varchar2(100);  -- bepaalt max aant. rijen danwel kolommen

  CONST_kleur_undef   constant kleur_type := '_';
  CONST_kleur_empty   constant kleur_type := ' ';
  CONST_kleur_default constant kleur_type := 'O';
  CONST_maxgen        constant natural := 1000;

  CONST_MAX_ITERATIONS constant natural:=500;

  type vak_ntb is table of kleur_type;

  type kleurpatroon_ntb is table of kleurstring;

  type regel is record
  ( vak_verwijzingen array
  , kleurpatroon     kleurpatroon_ntb -- bijv ('RR','BBB')
  , mogelijkheden    kleurpatroon_ntb -- bijv (' RR BBB','RR  BBB','RR BBB ')
  , ind_wijzigingen  boolean
  );
  type regel_ntb is table of regel;

  -- om een verwerkingsvolgorde van de regels te kunnen bijhouden
  -- wordt een associated array gebruik, waarvan de index uit twee
  -- delen bestaat. de eerste 6 posities worden gebruikt voor het
  -- aantal verschillende mogelijkheden dat nog voor de regel
  -- openstaat, de laatste 6 voor het unieke nummer waarmee
  -- de regel wordt aangeduidt, dit is tevens de waarde van het array
  -- element zelf.
  type regelvolgorde_tab is table of natural index by varchar2(12);

  type jap_puzzel_type is record
  ( aantal_rijen     natural
  , aantal_kolommen  natural
  , vakken           vak_ntb
  , regels           regel_ntb
  , regelvolgorde    regelvolgorde_tab
  );

  /****************************************************************************
   * package local procedures and functions
   ***************************************************************************/
  glob_dimensies       array;         -- glob_dimensies(1) geeft aantal rijen
                                      -- glob_dimensies(2) geeft aantal kolommen
  glob_detail_niveau   natural:=0;  -- geeft niveau van detaillering van logmeldingen aan

  glob_iteration_count natural:=0;

  /****************************************************************************
   * package local procedures and functions
   * general usage: debugging
   ***************************************************************************/
  procedure print
  ( a_line in varchar2
  , inspring_niveau in natural default 0
  , detail_niveau   in natural default 0
  )
  is
  begin
    if detail_niveau <= glob_detail_niveau
    then
      dbms_output.put_line (lpad(' ',inspring_niveau,' ')||a_line);
    end if;
  end print;

  procedure print
  ( a_lijst dimensie
  , inspring_niveau in natural default 0
  , detail_niveau   in natural default 0
  )
  is
    l_line kleurstring;
  begin
    for i1 in 1..a_lijst.count
    loop
      l_line := lpad(i1,3,'0')||': ';
      for i2 in 1..a_lijst(i1).count
      loop
        l_line := l_line || rpad(a_lijst(i1)(i2),3);
      end loop;
      print (l_line,inspring_niveau,detail_niveau);
    end loop;
  end print;

  procedure print
  ( a_jap_puzzel jap_puzzel_type
  , inspring_niveau in natural default 0
  , detail_niveau   in natural default 0
  )
  is
    l_line kleurstring;
    l_regelvolgorde varchar2(12);
    l_ind_wijzigingen varchar2(3);
  begin
    print ('JAP PUZZEL:',inspring_niveau,detail_niveau);
    for r in 1..a_jap_puzzel.aantal_rijen
    loop
      l_line := lpad(r,3,'0')||': ';
      for k in 1..a_jap_puzzel.aantal_kolommen
      loop
        l_line:=l_line||a_jap_puzzel.vakken(a_jap_puzzel.regels(r).vak_verwijzingen(k));
      end loop;
      print(l_line,inspring_niveau,detail_niveau);
    end loop;
    l_regelvolgorde := a_jap_puzzel.regelvolgorde.first;
    if l_regelvolgorde is not null
    then
      print('  ',inspring_niveau,detail_niveau);
      print ('Dit is de regelvolgorde:',inspring_niveau,detail_niveau);
      if a_jap_puzzel.regels(a_jap_puzzel.regelvolgorde(l_regelvolgorde)).ind_wijzigingen
      then
        l_ind_wijzigingen:='(*)';
      else
        l_ind_wijzigingen:='   ';
      end if;
      print (l_regelvolgorde||l_ind_wijzigingen||'=>'||a_jap_puzzel.regelvolgorde(l_regelvolgorde),inspring_niveau+2,detail_niveau);
      l_regelvolgorde := a_jap_puzzel.regelvolgorde.next(l_regelvolgorde);
      while l_regelvolgorde is not null
      loop
        if a_jap_puzzel.regels(a_jap_puzzel.regelvolgorde(l_regelvolgorde)).ind_wijzigingen
        then
          l_ind_wijzigingen:='(*)';
        else
          l_ind_wijzigingen:='   ';
        end if;
        print (l_regelvolgorde||l_ind_wijzigingen||'=>'||a_jap_puzzel.regelvolgorde(l_regelvolgorde),inspring_niveau+2,detail_niveau);
        l_regelvolgorde := a_jap_puzzel.regelvolgorde.next(l_regelvolgorde);
      end loop;
    end if;
  end print;

  procedure htmlprint
  ( a_jap_puzzel jap_puzzel_type
  )
  is
    l_cell_size constant natural := 2;
    l_line varchar2(1000);
    l_htmlkleur varchar2(60);
  begin
    print('<html>');
    print('<head>');
    print('<meta http-equiv=Content-Type content="text/html; charset=windows-1252">');
    print('</head>');
    print('<body lang=EN-US>');
    print('<table border=1'
          ||' width=' ||'400'--l_cell_size*a_jap_puzzel.aantal_kolommen*4
--          ||' height='||'100'--l_cell_size*a_jap_puzzel.aantal_rijen
          ||' cellspacing=0 cellpadding=0 '
          ||'style=''background:white;border-collapse:collapse;border:solid black 1''>');
    for r in 1..a_jap_puzzel.aantal_rijen
    loop
      print('<tr>',2);
      l_line := '<td'
--                ||' width=' ||trunc(100/a_jap_puzzel.aantal_kolommen)||'%'  --l_cell_size
--                ||' height='||trunc(100/a_jap_puzzel.aantal_rijen)--   ||'%'  --l_cell_size
                ||' width=2'
                ||' height=2'
                ||' style=''border:solid black 1';
      for k in 1..a_jap_puzzel.aantal_kolommen
      loop
        l_htmlkleur:= case a_jap_puzzel.vakken(a_jap_puzzel.regels(r).vak_verwijzingen(k))
                      when CONST_kleur_empty
                      then null                      else ';background:black'
                      end;
        print (l_line||l_htmlkleur||'''>'||chr(38)||'nbsp</td>', 4);
      end loop;
      print('</tr>',2);
    end loop;
    print('</table>');
    print('</body>');
    print('</html>');
  end htmlprint;

  /****************************************************************************
   * package local procedures and functions
   * general usage: conversion
   ***************************************************************************/
  function jap_puzzel_type#
  ( p_aantal_rijen       in natural
  , p_aantal_kolommen    in natural
  , p_vakken             in vak_ntb
  , p_regels             in regel_ntb
  , p_regelvolgorde      in regelvolgorde_tab
  ) return jap_puzzel_type
  is
    l_jap_puzzel jap_puzzel_type;
  begin
    l_jap_puzzel.aantal_rijen    := p_aantal_rijen;
    l_jap_puzzel.aantal_kolommen := p_aantal_kolommen;
    l_jap_puzzel.vakken          := p_vakken;
    l_jap_puzzel.regels          := p_regels;
    l_jap_puzzel.regelvolgorde   := p_regelvolgorde;
    return l_jap_puzzel;
  end jap_puzzel_type#;

  /****************************************************************************
   * package local procedures and functions
   ***************************************************************************/
  procedure track_iteration_count
  is
  begin
    glob_iteration_count:=glob_iteration_count+1;
    if glob_iteration_count > CONST_MAX_ITERATIONS
    then
      raise_application_error(-20000,'Max. aantal iteraties ('||CONST_MAX_ITERATIONS||') overschreden.');
    end if;
  end track_iteration_count;

  function offset
  ( p_rij         in    natural
  , p_kolom       in    natural
  )
  return natural
  is
    /* bereken een lineaire index voor een vak met x,y coordinaten */
  begin
    return ( (p_rij - 1 ) * glob_dimensies(2) + p_kolom );
  end offset;

  function repstr
  ( p_element in kleur_type
  , p_aantal  in natural
  )
  return varchar2
  is
  begin
    return lpad(p_element,p_aantal,p_element);
  end repstr;

  procedure add_index
  ( p_array in out array
  , p_index       in     natural
  )
  is
  begin
    begin
      p_array.extend;
    exception
      when collection_is_null
      then
        p_array:=array(null);
    end;
    p_array(p_array.last):=p_index;
  end add_index;

  function kleurpatroon_lengte
  ( p_kleurpatroon        in kleurpatroon_ntb
  )
  return natural
  is
    l_lengte natural := 0;
  begin
    for i in 1..p_kleurpatroon.count
    loop
      l_lengte:=l_lengte+length(p_kleurpatroon(i));
    end loop;
    return l_lengte+p_kleurpatroon.count-1;
  end kleurpatroon_lengte;

  procedure gen_mogelijkheden
  ( p_kleurpatroon        in     kleurpatroon_ntb
  , p_lengte              in     natural
  , p_trailingstrip       in     varchar2
  , p_template            in     varchar2
  , p_mogelijkheden       in out kleurpatroon_ntb
  )
  is
    l_kleurstring  kleurstring;
    l_kleurpatroon kleurpatroon_ntb := p_kleurpatroon;
  begin
    if p_mogelijkheden is not null and p_mogelijkheden.count>=CONST_maxgen
    then
      -- zet indicatie dat het totale spectrum aan mogelijkheden nu nog even niet bepaald wordt
      p_mogelijkheden(1):=null;
      return;
    end if;
    if p_kleurpatroon.count = 0
    then
      if p_lengte = 0 or repstr(CONST_kleur_empty, p_lengte) like p_template
      then
         --        a_teller := a_teller + 1;
         --        dbms_output.put_line(lpad(a_teller,5,'0')||' "'||repstr(CONST_kleur_empty,p_lengte)||p_trailingstrip||'"');
         begin
           p_mogelijkheden.extend;
         exception
           when collection_is_null
             then
               p_mogelijkheden:=kleurpatroon_ntb(null);
         end;
         p_mogelijkheden(p_mogelijkheden.last):=repstr(CONST_kleur_empty,p_lengte)||p_trailingstrip;
      end if;
    else
      l_kleurpatroon.trim;
      l_kleurstring:=p_kleurpatroon(p_kleurpatroon.last);
      for i in 0..p_lengte-kleurpatroon_lengte(p_kleurpatroon)
      loop
        if      l_kleurstring||repstr(CONST_kleur_empty,i)
           like substr(p_template,-length(l_kleurstring)-i)
        then
          gen_mogelijkheden
          ( l_kleurpatroon
          ,   p_lengte
            - i
            - case l_kleurpatroon.count
              when 0 then 0
                    else 1
              end
            - length(l_kleurstring)
          ,   case l_kleurpatroon.count
              when 0 then null
                     else CONST_kleur_empty
              end
            ||l_kleurstring
            ||repstr(CONST_kleur_empty, i)
            ||p_trailingstrip
          , substr
            ( p_template
            , 1
            ,   p_lengte
              - i
              - case l_kleurpatroon.count
                when 0 then 0
                      else 1
                end
              - length(l_kleurstring)
            )
          , p_mogelijkheden
          );
        end if;
      end loop;
    end if;
  end gen_mogelijkheden;

  function ggd_mogelijkheden
  ( p_mogelijkheden in kleurpatroon_ntb
  )
  return kleurstring
  is
    /*
     * bepaal aan de hand van de gegeven mogelijke oplossingen, de
     * 'grootste gemene deler'. Er zijn immers wellicht vakken die
     * in elke mogelijke oplossing dezelfde vulling krijgen!
     */
    l_kleurstring kleurstring := p_mogelijkheden(1);
  begin
    for i in 2..p_mogelijkheden.count
    loop
      for j in 1..length(l_kleurstring)
      loop
        if substr(l_kleurstring,j,1) <> CONST_kleur_undef
        then
          if substr(l_kleurstring,j,1) <> substr(p_mogelijkheden(i),j,1)
          then
            -- vervang element j door ongedefinieerde waarde
            l_kleurstring:=  substr(l_kleurstring,1,j-1)
                           ||CONST_kleur_undef
                           ||substr(l_kleurstring,j+1);
          end if;
        end if;
      end loop;
    end loop;
    return l_kleurstring;
  end ggd_mogelijkheden;

  procedure add_regel
  ( p_regel         in out regel_ntb
  , p_array         in     array
  , p_kleurpatroon  in     kleurpatroon_ntb
  )
  is
    /*
     *  voeg een element toe aan p_regel.
     *  p_array is een lijst van verwijzingen naar de vakken in het diagram.
     *  p_kleurpatroon is een lijst van kleurstrings, dus de condities in de
     *  kantlijn van het diagram.
     *  de indicator ind_wijzigingen wordt geinitialiseers.
    */
    l_regel regel;
  begin
    l_regel.vak_verwijzingen := p_array;
    l_regel.kleurpatroon     := p_kleurpatroon;
    l_regel.mogelijkheden    := null;
    gen_mogelijkheden
    ( p_kleurpatroon        => p_kleurpatroon
    , p_lengte              => p_array.count
    , p_trailingstrip       => null
    , p_template            => repstr(CONST_kleur_undef, p_array.count)
    , p_mogelijkheden       => l_regel.mogelijkheden
    );
--     print('De gegenereerde mogelijkheden:',4,20);
--     for i in 1..l_regel.mogelijkheden.count
--     loop
--       print(l_regel.mogelijkheden(i),4,20);
--     end loop;
    begin
      p_regel.extend;
    exception
      when collection_is_null
      then
        p_regel:=regel_ntb(null);
    end;
    l_regel.ind_wijzigingen:=true;
    print('Regel heeft '||l_regel.mogelijkheden.count||' mogelijke oplossingen',0,10);
    p_regel(p_regel.last):=l_regel;
  end add_regel;

  procedure add_kleurpatroon
  ( p_kleurpatroon        in out kleurpatroon_ntb
  , p_kleur               in     kleur_type
  , p_aantal              in     natural
  )
  is
  begin
    begin
      p_kleurpatroon.extend;
    exception
      when collection_is_null
      then
        p_kleurpatroon:=kleurpatroon_ntb(null);
    end;
    p_kleurpatroon(p_kleurpatroon.last):=repstr(p_kleur,p_aantal);
  end add_kleurpatroon;

  function jap_puzzel
  ( p_diagram in diagram
  )
  return jap_puzzel_type
  is
    l_aantal_rijen    natural;
    l_aantal_kolommen natural;
    l_vakken vak_ntb;
    l_regels regel_ntb;

    l_array         array;
    l_kleur         kleur_type;
    l_aantal        natural;
    l_kleurpatroon  kleurpatroon_ntb;
    l_regelvolgorde_tab regelvolgorde_tab;
    l_regelvolgorde varchar2(12);
  begin
    print('opbouwen diagram japanse puzzel', 0, 10);
    -- vul om te beginnen de vakken
    if p_diagram.count <> 2
    then
      raise_application_error (-20000, 'Een diagram moet uit rijen en kolommen bestaan');
    end if;
    l_vakken := vak_ntb(CONST_kleur_undef);
    l_aantal_rijen    := p_diagram(1).count;
    l_aantal_kolommen := p_diagram(2).count;
    glob_dimensies:=array(l_aantal_rijen, l_aantal_kolommen);
    l_vakken.extend(l_aantal_rijen*l_aantal_kolommen-1,1);
    -- definieer nu de regels
    for d in 1..2
    loop
      print('opbouwen dimensie '||d,2,10);
      for i in 1..glob_dimensies(d)
      loop
        print('opbouwen rij nummer '||i,2,15);
        -- stel de array (verwijzingen naar vakken) vast
        l_array := null;
        for j in 1..glob_dimensies(3-d)
        loop
          add_index
          ( l_array
          , offset
            ( case d when 1 then i else j end
            , case d when 1 then j else i end
            )
          );
          print('bestaande uit vak '||offset
            ( case d when 1 then i else j end
            , case d when 1 then j else i end
            )||' ( '
                 ||case d when 1 then i else j end||', '
                 ||case d when 1 then j else i end||')',4,20);
        end loop;
        -- stel de kleurpatronen vast
        l_kleurpatroon := null;
        for k in 1..p_diagram(d)(i).count
        loop
          print('opbouwen kleurpatroon nummer '||k,2,15);
          -- parse de opgegeven kleur en aantal, kleur kan zijn weggelaten
          l_kleur := substr(p_diagram(d)(i)(k),1,1);
          if instr('123456789',l_kleur)=0
          then
            -- er is inderdaad als eerste letter als kleur opgegeven
            l_aantal := to_number(substr(p_diagram(d)(i)(k),2));
            print('opgegeven kleur '||l_kleur||' aantal: '||l_aantal,4,15);
          else
            -- correctie: geen kleur opgegeven
            l_kleur := CONST_kleur_default;
            l_aantal:= to_number(p_diagram(d)(i)(k));
            print('default kleur '||l_kleur||' aantal: '||l_aantal,4,15);
          end if;
          add_kleurpatroon(l_kleurpatroon, l_kleur, l_aantal);
        end loop;
        -- voeg de regel toe
        add_regel(l_regels, l_array, l_kleurpatroon);
        l_regelvolgorde_tab(  lpad(l_regels(l_regels.last).mogelijkheden.count,6,'0')
                            ||lpad(l_regels.count,6,'0')
                           ) := l_regels.count;
      end loop;
    end loop;
    -- toon de regelvolgorde
    print ('Dit is de regelvolgorde:',0,10);
    l_regelvolgorde := l_regelvolgorde_tab.first;
    print (l_regelvolgorde,2,10);
    l_regelvolgorde := l_regelvolgorde_tab.next(l_regelvolgorde);
    while l_regelvolgorde is not null
    loop
      print (l_regelvolgorde,2,10);
      l_regelvolgorde := l_regelvolgorde_tab.next(l_regelvolgorde);
    end loop;

    return  jap_puzzel_type#
            ( p_aantal_rijen     => l_aantal_rijen
            , p_aantal_kolommen  => l_aantal_kolommen
            , p_vakken           => l_vakken
            , p_regels           => l_regels
            , p_regelvolgorde    => l_regelvolgorde_tab
            );
  end jap_puzzel;

  procedure verminder_mogelijkheden
  ( p_jap_puzzel in out jap_puzzel_type
  , p_regelvolgorde    in     varchar2
  )
  is
    -- beperk de voorberekende mogelijkheden adhv de huidige vulling van het diagram
    l_kleurstring kleurstring;
    l_mogelijkheden kleurpatroon_ntb;
    l_regelnr natural;
  begin
    print ('Verminder de mogelijkheden voor regelvolgorde '||p_regelvolgorde,0,10);
    l_regelnr := p_jap_puzzel.regelvolgorde(p_regelvolgorde);
    for i in 1..p_jap_puzzel.regels(l_regelnr).vak_verwijzingen.count
    loop
      l_kleurstring:=l_kleurstring
      ||p_jap_puzzel.vakken(p_jap_puzzel.regels(l_regelnr).vak_verwijzingen(i));
    end loop;
    print ('Verminder de mogelijkheden voor regel '||l_regelnr||' adhv "'||l_kleurstring||'"',0,10);
    if p_jap_puzzel.regels(l_regelnr).mogelijkheden(1) is null
    then
      print ('Eerst mogelijkheden opnieuw bepalen',0,10);
      gen_mogelijkheden
      ( p_kleurpatroon        => p_jap_puzzel.regels(l_regelnr).kleurpatroon
      , p_lengte              => length(p_jap_puzzel.regels(l_regelnr).mogelijkheden(2))
      , p_trailingstrip       => null
      , p_template            => l_kleurstring
      , p_mogelijkheden       => l_mogelijkheden
      );
      p_jap_puzzel.regels(l_regelnr).mogelijkheden:=l_mogelijkheden;
    end if;
    if p_jap_puzzel.regels(l_regelnr).mogelijkheden(1) is not null
    then
      l_mogelijkheden := null;
      for i in 1..p_jap_puzzel.regels(l_regelnr).mogelijkheden.count
      loop
        if p_jap_puzzel.regels(l_regelnr).mogelijkheden(i) like l_kleurstring
        then
          begin
            l_mogelijkheden.extend;
          exception
            when collection_is_null
              then
                l_mogelijkheden:=kleurpatroon_ntb(null);
          end;
          l_mogelijkheden(l_mogelijkheden.last):=p_jap_puzzel.regels(l_regelnr).mogelijkheden(i);
        else
          print('mogelijkheid "'||p_jap_puzzel.regels(l_regelnr).mogelijkheden(i)||'" valt af.',2,20);
        end if;
      end loop;
      p_jap_puzzel.regels(l_regelnr).mogelijkheden:=l_mogelijkheden;
    end if;
    p_jap_puzzel.regelvolgorde.delete(p_regelvolgorde);
    p_jap_puzzel.regelvolgorde(lpad(l_mogelijkheden.count,6,'0')
                          ||lpad(l_regelnr,6,'0')
                         ) := l_regelnr;
  end verminder_mogelijkheden;

  procedure zet_regel
  ( p_jap_puzzel in out jap_puzzel_type
  , p_regelnr    in     natural
  )
  is
    l_kleurstring kleurstring;
    l_kleurstring_oud kleurstring;
    l_regelnr natural;
  begin
    if p_jap_puzzel.regels(p_regelnr).mogelijkheden(1) is null
    then
      verminder_mogelijkheden
        (p_jap_puzzel, lpad(p_jap_puzzel.regels(l_regelnr).mogelijkheden.count,6,'0')||lpad(l_regelnr,6,'0'));
    end if;    
    l_kleurstring:=ggd_mogelijkheden(p_jap_puzzel.regels(p_regelnr).mogelijkheden);
    print ('Zet diagram adhv regel '||p_regelnr||' met "'||l_kleurstring||'"',0,10);
    for i in 1..length(l_kleurstring)
    loop
      l_kleurstring_oud:=p_jap_puzzel.vakken(p_jap_puzzel.regels(p_regelnr).vak_verwijzingen(i));
      p_jap_puzzel.vakken(p_jap_puzzel.regels(p_regelnr).vak_verwijzingen(i))
        := substr(l_kleurstring,i,1);
      -- bepaal of er 'in de andere rij/kolom' iets is gewijzigd
      if l_kleurstring_oud<>substr(l_kleurstring,i,1)
      then
        -- is dit een regel in een rij of in een kolom
        if p_regelnr <= p_jap_puzzel.aantal_rijen
        then
          l_regelnr := p_jap_puzzel.aantal_rijen+i;
        else
          l_regelnr := i;
        end if;
        p_jap_puzzel.regels(l_regelnr).ind_wijzigingen:=true;
        verminder_mogelijkheden
        (p_jap_puzzel, lpad(p_jap_puzzel.regels(l_regelnr).mogelijkheden.count,6,'0')||lpad(l_regelnr,6,'0'));
      end if;
    end loop;
    -- in deze regel is net alles bijgewerkt; geen wijzigingen meer
    p_jap_puzzel.regels(p_regelnr).ind_wijzigingen:=false;
  end zet_regel;

  function oplossen
  ( p_jap_puzzel in jap_puzzel_type
  )
  return jap_puzzel_type
  is
    l_jap_puzzel jap_puzzel_type := p_jap_puzzel;
    l_regelvolgorde varchar2(12);
    l_regelvolgorde_next varchar2(12);
    l_regelnr natural;
    e_oplossing_gevonden exception;
    procedure bepaal_next_regel
    is
    begin
      track_iteration_count;
      l_regelvolgorde := l_jap_puzzel.regelvolgorde.first;
      if l_regelvolgorde is not null
      then
        while not l_jap_puzzel.regels(l_jap_puzzel.regelvolgorde(l_regelvolgorde)).ind_wijzigingen
        loop
          l_regelvolgorde := l_jap_puzzel.regelvolgorde.next(l_regelvolgorde);
          exit when l_regelvolgorde is null;
        end loop;
      end if;
    end bepaal_next_regel;
  begin
    --print ('Oplossen aanroep *******************************************************');
    print (l_jap_puzzel, 0, 10);
    --print ('Oplossen aanroep *******************************************************');
    bepaal_next_regel;
    while l_regelvolgorde is not null
    loop
      l_regelnr := l_jap_puzzel.regelvolgorde(l_regelvolgorde);
      print('Oplossen van de puzzel adhv regel '||l_regelnr||' --------------------------',0,10);
      -- zet de overblijvende ggd van deze regel in het diagram
      zet_regel (l_jap_puzzel, l_regelnr);
      -- verwijder definitief uit regelvolgorde indien precies 1 oplossing
      if l_jap_puzzel.regels(l_regelnr).mogelijkheden.count = 1
      then
        l_jap_puzzel.regelvolgorde.delete(l_regelvolgorde);
      end if;
      -- bepaal de volgende regel
      bepaal_next_regel;
      print (l_jap_puzzel, 2, 10);
    end loop;
    if l_jap_puzzel.regelvolgorde.count>0
    then
      declare
        l_jap_puzzel_try jap_puzzel_type;
      begin
        l_regelvolgorde := l_jap_puzzel.regelvolgorde.first;
        l_regelnr := l_jap_puzzel.regelvolgorde(l_regelvolgorde);
        for i in 1..l_jap_puzzel.regels(l_regelnr).mogelijkheden.count
        loop
          -- tijd voor het maken van een 'educated guess'
          print ('educated guess',0,10);
          print (l_jap_puzzel,0,10);
          begin
            l_jap_puzzel_try:=l_jap_puzzel;
            l_jap_puzzel.regels(l_regelnr).mogelijkheden:=kleurpatroon_ntb(l_jap_puzzel.regels(l_regelnr).mogelijkheden(i));
            l_jap_puzzel_try:=oplossen(l_jap_puzzel_try);
            return l_jap_puzzel_try;
          exception
          when e_oplossing_gevonden
          then
            l_jap_puzzel := l_jap_puzzel_try;
            raise e_oplossing_gevonden;
          when others
          then
            null;
          end;
        end loop;
      end;
    else
      raise e_oplossing_gevonden;
    end if;
    return null;
  exception
  when e_oplossing_gevonden
  then
    return l_jap_puzzel;
  end oplossen;

  /****************************************************************************
   * package global procedures and functions
   ***************************************************************************/
  procedure oplossen
  ( p_diagram in diagram
  )
  is
  begin
    glob_iteration_count:=0;
    print
    ('Dit betreft een japanse puzzel met afmetingen '
      ||p_diagram(1).count||'x'||p_diagram(2).count
    , 0, 10
    );
    print ('De kleurpatronen:', 0, 10);
    for d in 1..2
    loop
      case d
        when 1 then print ('de rijen:', 0, 10);
               else print ('de kolommen:', 0, 10);
      end case;
      print (p_diagram(d), 0, 10);
    end loop;
    htmlprint(oplossen(jap_puzzel(p_diagram)));
  end oplossen;
end jap;
/
