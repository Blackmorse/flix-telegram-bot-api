mod JsonExt {
    use Util.Json.{Json, JsonError, JString, FromJson, JsonPath, JNumber}
    use Util.Json.JsonPath.JsonStep
    use Util.Json.JsonError.DecodeErrorKind

    pub def getAsString(key: String, json: Json): Result[JsonError, String] = 
        match FromJson.getAtKey(key, json) {
            case Ok(JString(s)) => Ok(s)
            case Ok(_) => 
                DecodeErrorKind.TypeMismatch("Expected a string")
                |> JsonError.Decode(JsonPath(JsonStep.Key(key) :: Nil)) 
                |> Err
            case Err(e) => Err(e)
        }

    pub def getAsStringFromPath(p: JsonPath, json: Json): Result[JsonError, String] = 
        match FromJson.getAtPath(p, json) {
            case Ok(JString(s)) => Ok(s)
            case Ok(_) => 
                DecodeErrorKind.TypeMismatch("Expected a string")
                |> JsonError.Decode(p) 
                |> Err
            case Err(e) => Err(e)
        }

    // In case of float value will round it
    pub def getAsInt64(key: String, json: Json): Result[JsonError, Int64] =
        match FromJson.getAtKey(key, json) {
            case Ok(JNumber(n)) => 
                BigDecimal.tryToInt64(n) 
                |> Option.toOk(JsonError.Decode(JsonPath(JsonStep.Key(key) :: Nil), DecodeErrorKind.TypeMismatch("Expected an integer number")))
            case Ok(_) => 
                DecodeErrorKind.TypeMismatch("Expected a number")
                |> JsonError.Decode(JsonPath(JsonStep.Key(key) :: Nil)) 
                |> Err
            case Err(e) => Err(e)
        }

    pub def getAsInt64FromPath(p: JsonPath, json: Json): Result[JsonError, Int64] = 
        match FromJson.getAtPath(p, json) {
            case Ok(JNumber(n)) => 
                BigDecimal.tryToInt64(n) 
                |> Option.toOk(JsonError.Decode(p, DecodeErrorKind.TypeMismatch("Expected an integer number")))
            case Ok(_) => 
                DecodeErrorKind.TypeMismatch("Expected a number")
                |> JsonError.Decode(p) 
                |> Err
            case Err(e) => Err(e)
        }

    pub def getAsArray(key: String, json: Json): Result[JsonError, Vector[Json]] = 
        match FromJson.getAtKey(key, json) {
            case Ok(Util.Json.JArray(arr)) => Ok(arr)
            case Ok(_) => 
                DecodeErrorKind.TypeMismatch("Expected '${key}' to be an array")
                |> JsonError.Decode(JsonPath(JsonStep.Key(key) :: Nil)) 
                |> Err
            case Err(e) => Err(e)
        }
}
