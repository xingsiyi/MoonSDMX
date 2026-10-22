# Preserve reported values and metadata

The exchange model keeps reported values as text and represents an omitted value separately from zero. Numeric conversion is explicit and bounded, because an implicit binary float conversion would lose decimal precision and prevent faithful re-export. Attribute attachment is part of the structure and is validated across observations rather than silently choosing the last value.
