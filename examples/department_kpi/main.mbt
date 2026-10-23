///|
fn main raise {
  let departments = @sdmx.CodeList::new("DEPTS", [
    ("OPS", "Operations"),
    ("SUPPORT", "Support"),
  ])
  let structure = @sdmx.Structure::new(
    @sdmx.StructureRef::new("DEMO", "KPI", "1.0"),
    [
      @sdmx.Component::new("DEPT", @sdmx.Dimension, @sdmx.Coded(departments)),
      @sdmx.Component::new("TIME_PERIOD", @sdmx.TimeDimension, @sdmx.Period),
      @sdmx.Component::new("TICKETS", @sdmx.Measure, @sdmx.Integer),
      @sdmx.Component::new(
        "UNIT",
        @sdmx.Attribute(["DEPT"]),
        @sdmx.Text,
        required=true,
      ),
      @sdmx.Component::new(
        "QUALITY",
        @sdmx.Attribute(["DEPT", "TIME_PERIOD"]),
        @sdmx.Text,
      ),
    ],
  )
  let csv = "STRUCTURE,STRUCTURE_ID,QUALITY,UNIT,TICKETS,TIME_PERIOD,DEPT\n" +
    "datastructure,DEMO:KPI(1.0),final,count,120,2026-01,OPS\n" +
    "datastructure,DEMO:KPI(1.0),provisional,count,,2026-02,OPS\n" +
    "datastructure,DEMO:KPI(1.0),final,count,80,2026-01,SUPPORT\n"
  let message = @sdmx.decode_csv2(structure, csv)
  assert_eq(message.dataset().length(), 3)
  assert_eq(
    message.dataset().get(["OPS", "2026-02"]).unwrap().measures()[0],
    None,
  )
  let json = message.encode_json2(
    id="departments",
    sender="DEMO",
    prepared="2026-10-23T00:00:00Z",
  )
  assert_eq(
    @sdmx.decode_json2(json, expected=Some(structure))
    .dataset()
    .sorted()
    .observations(),
    message.dataset().sorted().observations(),
  )
  let unknown_department = csv.replace_all(old="SUPPORT", new="GHOST")
  let rejected = try {
    ignore(@sdmx.decode_csv2(structure, unknown_department))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  let conflicting_units = csv.replace_all(
    old="provisional,count",
    new="provisional,hours",
  )
  let conflict = try {
    ignore(@sdmx.decode_csv2(structure, conflicting_units))
    false
  } catch {
    _ => true
  }
  assert_true(conflict)
  println(
    "department-kpi: 3 typed observations exchanged; unknown department and inconsistent department unit rejected",
  )
}
