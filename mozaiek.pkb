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
  CONST_MAX_ITERATIONS constant pls_integer:=500;

  subtype telling_type is simple_integer;
  subtype index_type is simple_integer;

  type ntb_indices_type is table of index_type;

  subtype status_type  is char(1) not null; -- gevuld 'x', ongevuld '-' of onbepaald ' '

  type dimensies_type is
  record
  ( rijen     telling_type default 0
  , kolommen  telling_type default 0
  );

  type ntb_vakken_type is table of status_type;

  type aanwijzingen_type is
  record
  ( aantal  telling_type default 0
  , blok    ntb_indices_type
  );

  type ntb_aanwijzingen_type is table of aanwijzingen_type;

  type puzzel_type is
  record
  ( dimensies           dimensies_type
  , vakken              ntb_vakken_type
  , aanwijzingen        ntb_aanwijzingen_type
  );

  function opgelost
  ( pi_puzzel in puzzel_type
  )
  return puzzel_type
  is
  begin
    null;/*todo*/
  end opgelost;

  function puzzel_van_diagram
  ( pi_diagram in diagram
  )
  return puzzel_type
  is
    -- initialiseer nieuwe puzzel op basis van gegeven diagram
    l_puzzel puzzel_type;
  begin
    -- initialiseer de vakken
    l_puzzel.dimensies.rijen:=pi_diagram.count;
    l_puzzel.dimensies.kolommen:=length(pi_diagram(1));
    for i in 1..l_puzzel.dimensies.rijen
    -- voor elke regel i
    loop
      for j in 1..l_puzzel.dimensies.rijen
      -- voor elke kolom j
      loop
        null;
      end loop;
    end loop;
    null;/*todo*/

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
    dbms_output.put_line(pi_puzzel.dimensies.rijen);
    dbms_output.put_line(pi_puzzel.dimensies.kolommen);
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
