mod JsonExt.Test {
    use Util.Json.{Json, JString, JObject, JArray, JsonError, JsonPath, JNumber}
    use Util.Json.JsonPath.JsonStep
    use Util.Json.JsonError.DecodeErrorKind
    use Assert.{assertEq, fail}

    @Test
    def testGetAsStringHappyPath(): Unit \ Assert = 
        let json = JObject(Map#{"key" => JString("value")});
        assertEq(expected = Ok("value"), JsonExt.getAsString("key", json))

    @Test
    def testGetAsStringDifferentType(): Unit \ Assert = 
        let json = JObject(Map#{"key" => JObject(Map#{})});
        match JsonExt.getAsString("key", json) {
            case Err(JsonError.Decode(JsonPath(JsonStep.Key("key") :: Nil), DecodeErrorKind.TypeMismatch("Expected a string"))) => ()
            case _ => fail("Expected a decode error")
        }

    @Test
    def testGetAsStringKeyNotFound(): Unit \ Assert = 
        let json = JObject(Map#{"other_key" => JString("value")});
        match JsonExt.getAsString("key", json) {
            case Err(_) => () // Expected error
            case Ok(_) => fail("Expected an error, but got Ok")
        }

    @Test
    def testGetAsArrayHappyPath(): Unit \ Assert = 
        let json = JObject(Map#{"key" => JArray(Vector#{JString("a"), JString("b")})});
        assertEq(expected = Ok(Vector#{JString("a"), JString("b")}), JsonExt.getAsArray("key", json))

    @Test
    def testGetAsArrayDifferentType(): Unit \ Assert = 
        let json = JObject(Map#{"key" => JObject(Map#{})});
        match JsonExt.getAsArray("key", json) {
            case Err(JsonError.Decode(JsonPath(JsonStep.Key("key") :: Nil), DecodeErrorKind.TypeMismatch("Expected 'key' to be an array"))) => ()
            case _ => fail("Expected a decode error")
        }

    @Test
    def testGetAsArrayKeyNotFound(): Unit \ Assert = 
        let json = JObject(Map#{"other_key" => JArray(Vector#{})});
        match JsonExt.getAsArray("key", json) {
            case Err(_) => () // Expected error
            case Ok(_) => fail("Expected an error, but got Ok")
        }

    @Test
    def testGetAsInt64HappyPath(): Unit \ Assert = 
        match BigDecimal.fromString("42") {
            case Some(n) => 
                let json = JObject(Map#{"key" => JNumber(n)});
                assertEq(expected = Ok(42i64), JsonExt.getAsInt64("key", json))
            case None => fail("Failed to create BigDecimal from string")
        }

    @Test
    def testGetAsInt64DifferentType(): Unit \ Assert = 
        let json = JObject(Map#{"key" => JString("not a number")});
        match JsonExt.getAsInt64("key", json) {
            case Err(JsonError.Decode(JsonPath(JsonStep.Key("key") :: Nil), DecodeErrorKind.TypeMismatch("Expected a number"))) => ()
            case _ => fail("Expected a decode error")
        }

    @Test
    def testGetAsInt64KeyNotFound(): Unit \ Assert = 
        let json = JObject(Map#{});
        match JsonExt.getAsInt64("key", json) {
            case Err(_) => () // Expected error
            case Ok(_) => fail("Expected an error, but got Ok")
        }

    @Test
    def testGetAsInt64FloatNumber(): Unit \ Assert = 
        match BigDecimal.fromString("42.4") {
            case Some(n) => 
                let json = JObject(Map#{"key" => JNumber(n)});
                assertEq(expected = Ok(42i64), JsonExt.getAsInt64("key", json))
            case None => fail("Failed to create BigDecimal from string")
        }

    @Test
    def testGetAsInt64TooBigNumber(): Unit \ Assert = 
        match BigDecimal.fromString("9223372036854775808") { // 2^63, which is too big for Int64
            case Some(n) => 
                let json = JObject(Map#{"key" => JNumber(n)});
                match JsonExt.getAsInt64("key", json) {
                    case Err(JsonError.Decode(JsonPath(JsonStep.Key("key") :: Nil), DecodeErrorKind.TypeMismatch("Expected an integer number"))) => ()
                    case _ => fail("Expected a decode error for too big number")
                }
            case None => fail("Failed to create BigDecimal from string")
        }

    @Test
    def testGetStringFromPathHappyPath(): Unit \ Assert = 
        let json = JObject(Map#{"key" => JObject(Map#{"nested" => JString("value")})});
        let path = JsonPath(JsonStep.Key("key") :: JsonStep.Key("nested") :: Nil);
        assertEq(expected = Ok("value"), JsonExt.getAsStringFromPath(path, json))

    @Test
    def testGetStringFromPathDifferentType(): Unit \ Assert = 
        let json = JObject(Map#{"key" => JObject(Map#{"nested" => JObject(Map#{})})});
        let path = JsonPath(JsonStep.Key("key") :: JsonStep.Key("nested") :: Nil);
        match JsonExt.getAsStringFromPath(path, json) {
            case Err(JsonError.Decode(p, DecodeErrorKind.TypeMismatch("Expected a string"))) if p == path => ()
            case _ => fail("Expected a decode error for different type")
        }

    @Test
    def testGetStringFromPathKeyNotFound(): Unit \ Assert = 
        let json = JObject(Map#{"key" => JObject(Map#{})});
        let path = JsonPath(JsonStep.Key("key") :: JsonStep.Key("nested") :: Nil);
        match JsonExt.getAsStringFromPath(path, json) {
            case Err(_) => () // Expected error
            case Ok(_) => fail("Expected an error, but got Ok")
        }

    @Test
    def testGetInt64FromPathHappyPath(): Unit \ Assert =
        match BigDecimal.fromString("42") {
            case Some(n) =>
                let json = JObject(Map#{"key" => JObject(Map#{"nested" => JNumber(n)})});
                let path = JsonPath(JsonStep.Key("key") :: JsonStep.Key("nested") :: Nil);
                assertEq(expected = Ok(42i64), JsonExt.getAsInt64FromPath(path, json))
            case None => fail("Failed to create BigDecimal from string")
        }

    @Test
    def testGetInt64FromPathDifferentType(): Unit \ Assert =
        let json = JObject(Map#{"key" => JObject(Map#{"nested" => JString("not a number")})});
        let path = JsonPath(JsonStep.Key("key") :: JsonStep.Key("nested") :: Nil);
        match JsonExt.getAsInt64FromPath(path, json) {
            case Err(JsonError.Decode(p, DecodeErrorKind.TypeMismatch("Expected a number"))) if p == path => ()
            case _ => fail("Expected a decode error for different type")
        }

    @Test
    def testGetInt64FromPathKeyNotFound(): Unit \ Assert =
        let json = JObject(Map#{"key" => JObject(Map#{})});
        let path = JsonPath(JsonStep.Key("key") :: JsonStep.Key("nested") :: Nil);
        match JsonExt.getAsInt64FromPath(path, json) {
            case Err(_) => () // Expected error
            case Ok(_) => fail("Expected an error, but got Ok")
        }

    @Test
    def testGetInt64FromPathFloatNumber(): Unit \ Assert =
        match BigDecimal.fromString("42.4") {
            case Some(n) =>
                let json = JObject(Map#{"key" => JObject(Map#{"nested" => JNumber(n)})});
                let path = JsonPath(JsonStep.Key("key") :: JsonStep.Key("nested") :: Nil);
                assertEq(expected = Ok(42i64), JsonExt.getAsInt64FromPath(path, json))
            case None => fail("Failed to create BigDecimal from string")
        }

    @Test
    def testGetInt64FromPathTooBigNumber(): Unit \ Assert =
        match BigDecimal.fromString("9223372036854775808") { // 2^63, too big for Int64
            case Some(n) =>
                let json = JObject(Map#{"key" => JObject(Map#{"nested" => JNumber(n)})});
                let path = JsonPath(JsonStep.Key("key") :: JsonStep.Key("nested") :: Nil);
                match JsonExt.getAsInt64FromPath(path, json) {
                    case Err(JsonError.Decode(p, DecodeErrorKind.TypeMismatch("Expected an integer number"))) if p == path => ()
                    case _ => fail("Expected a decode error for too big number")
                }
            case None => fail("Failed to create BigDecimal from string")
        }
}
