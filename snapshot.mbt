///|
fn hash_field(hasher : @crypto.SHA256, value : String) -> Unit {
  let bytes = @utf8.encode(value[:])
  hasher.update(bytes.length().to_uint64().to_be_bytes())
  hasher.update(bytes)
}

///|
/// A deterministic content fingerprint, not a signature or authentication check.
pub fn Dataset::fingerprint(self : Dataset) -> String raise SdmxError {
  let hasher = @crypto.SHA256::new()
  hash_field(hasher, "moonsdmx.dataset/1")
  hash_field(hasher, self.structure.to_profile_json())
  let ordered = self.rows.copy()
  ordered.sort_by((a, b) => a.key_token().lexical_compare(b.key_token()))
  hasher.update(ordered.length().to_uint64().to_be_bytes())
  for row in ordered {
    for value in row.key {
      hash_field(hasher, value)
    }
    for group in [row.measures, row.attributes] {
      for value in group {
        match value {
          None => hasher.update(b"\x00")
          Some(text) => {
            hasher.update(b"\x01")
            hash_field(hasher, text)
          }
        }
      }
    }
  }
  @crypto.bytes_to_hex_string(hasher.finalize())
}

///|
pub fn Structure::fingerprint(self : Structure) -> String raise SdmxError {
  let hasher = @crypto.SHA256::new()
  hash_field(hasher, "moonsdmx.structure/1")
  hash_field(hasher, self.to_profile_json())
  @crypto.bytes_to_hex_string(hasher.finalize())
}
