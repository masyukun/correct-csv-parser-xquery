xquery version "1.0-ml";

declare namespace csv = "http://matthewroyal.com/csv";

declare variable $csv as xs:string := "http://matthewroyal.com/csv";


(:~
    Join a sequence of codepoints into a xs:string
:)
declare function local:joinCodes($codepoints) as xs:string {
  fn:string-join( for $c in $codepoints return fn:codepoints-to-string($c) )
};


(:~
    CORRECT CSV PARSER, author: Matthew Royal
    
    This CSV parser correctly parses CSV files with escaped quotation marks ("") 
    and carriage returns in column data. It is probably slower than other parsers, 
    because the XQuery language standard does not support several key Regex features
    and relies on parsing the file one character at a time instead.

    If your column data contains these escaped characters, to my knowledge this is 
    currently the only XQuery-based CSV-to-XML converter that can parse them properly.
    If your data contains no such escape sequences, you will get much better performance
    using a different parser.
  
    GRAMMAR:
     file = [header CRLF] record *(CRLF record) [CRLF]
     header = field *(COMMA field)
     record = field *(COMMA field)
     field = (escaped / non-escaped)
     escaped = DQUOTE *(TEXTDATA / COMMA / CR / LF / 2DQUOTE) DQUOTE
     non-escaped = *TEXTDATA
     COMMA = %x2C
     CR = %x0D ;as per section 6.1 of RFC 2234 [2]
     DQUOTE =  %x22 ;as per section 6.1 of RFC 2234 [2]
     LF = %x0A ;as per section 6.1 of RFC 2234 [2]
     CRLF = CR LF ;as per section 6.1 of RFC 2234 [2]
     TEXTDATA =  %x20-21 / %x23-2B / %x2D-7E


    Parameters:
      $file as xs:string -- contents of CSV file to parse
      $header as xs:boolean -- indicates that the first row of the file is the header.
:)
declare function local:parseFile(
  $file as xs:string, 
  $header as xs:boolean
) as element()* {

  let $mem := map:new(())
  let $fileLength := fn:string-length($file)
  let $_ := map:put($mem, "row", 1)
  let $_ := map:put($mem, "fieldNum", 1)
  let $_ := map:put($mem, "fields", 1)
  let $_ := map:put($mem, "origin", 1)
  let $_ := map:put($mem, "escaped", ())
  let $inputCodepoints := fn:string-to-codepoints($file)
  let $_ :=
    for $l at $i in $inputCodepoints
    let $letter := fn:codepoints-to-string($l)
    return
      (: Quote mark:)
      if ($letter = '"') then
        if (fn:not(map:get($mem, "escaped")) and (local:joinCodes($inputCodepoints[$i - 1]) = "," or fn:not(local:joinCodes($inputCodepoints[$i - 1])))) then
          map:put($mem, "escaped", '"')
        else if (map:get($mem, "escaped") and local:joinCodes($inputCodepoints[$i - 1]) != '"' and local:joinCodes($inputCodepoints[$i + 1]) != '"') then
          map:put($mem, "escaped", ())
        else ()
      (: Comma; newline, end of row; End of file :)
      else if ( (($letter = ',' or $letter = '&#xa;') and not(map:get($mem, "escaped"))) or $i = $fileLength ) then
        let $fieldNum := map:get($mem, "fieldNum")
        (: Keep track of how many fields there are :)
        let $fieldMax := if ($fieldNum > map:get($mem, "fields")) then $fieldNum else map:get($mem, "fields")
        let $row := map:get($mem, "row")
        let $o := map:get($mem, "origin")
        let $fieldValue := local:joinCodes($inputCodepoints[$o to (if ($fileLength = $i) then $i else $i - 1)])
        let $_ := 
          if ($row = 1 and $header) then
            map:put($mem, "header-" || xs:string($fieldNum), $fieldValue)
          else
            map:put($mem, xs:string($row) || "-" || xs:string($fieldNum), $fieldValue)
        let $_ := map:put($mem, "fieldNum", $fieldNum + 1)
        let $_ := map:put($mem, "fields", $fieldMax)
        let $_ := map:put($mem, "origin", $i + 1)
        return 
          if ($letter = '&#xa;' and not(map:get($mem, "escaped"))) then
            let $_ := map:put($mem, "row", $row + 1)
            let $_ := map:put($mem, "fieldNum", 1)
            return map:put($mem, "escaped", ())
          else 
            map:put($mem, "escaped", ())
      else ()
  return 
    let $fields := map:get($mem, "fields")
    let $rows   := map:get($mem, "row")
    for $r in 1 to $rows
    return
      if ($r = 1 and $header) then () else (: Skip the header row :) 
      element { fn:QName( $csv, "row" ) }
      {
        if ($header) then
          attribute {xs:QName("num")} {$r - 1}
        else
          attribute {xs:QName("num")} {$r}
        ,
        for $f in 1 to $fields
        return 
          if (
              map:get($mem, xs:string($r) || "-" || xs:string($f))
          ) then
            element 
            { 
              if ($header) then
                let $default := "field" || xs:string($f)
                let $custom := fn:replace(map:get($mem, "header-"||xs:string($f)), '["| ]', '')
                return fn:QName( $csv, if ($custom = "") then $default else $custom )
              else
                fn:QName($csv, "field" || xs:string($f))
            } 
            { map:get($mem, xs:string($r) || "-" || xs:string($f)) }
          else ()
      }
};


let $fileContents := '"DRUG_CONCEPT_ID","INGREDIENT_CONCEPT_ID","AMOUNT_VALUE","AMOUNT_UNIT","CONCENTRATION_VALUE","CONCENTRATION_ENUM_UNIT","CONCENTRATION_DENOM_UNIT","VALID_START_DATE","VALID_END_DATE","INVALID_REASON"|
19035821,19069022,8.3,"mg",,,,1970-01-01,2099-12-31,|
19035837,1351461,,,100,"mg","ml",1970-01-01,2009-09-06,D|
19035864,19132972,,,150,"mg","ml",1970-01-01,2099-12-31,|
19035865,1163944,,,20,"mg","ml",1970-01-01,2099-12-31,|
19035867,1163944,,,20,"mg","ml",1970-01-01,2099-12-31,|
19035932,1351779,50,"mg",,,,1970-01-01,2099-12-31,|
19035937,1163944,,,40,"mg","ml",1970-01-01,2099-12-31,|
19035962,1163944,,,20,"mg","ml",1970-01-01,2099-12-31,|
19035963,1201620,,,2,"mg","ml",1970-01-01,2099-12-31,|
19035965,1201620,,,2,"mg","ml",1970-01-01,2099-12-31,|
19036008,19035704,500,"mg",,,,1970-01-01,2099-12-31,|
19036138,1159811,,,.8,"mg","ml",1970-01-01,2099-12-31,|
19036172,933952,,,.8,"mg","ml",1970-01-01,2099-12-31,|
19036201,1135766,,,1,"mg","ml",1970-01-01,2099-12-31,|
19036208,933952,,,10,"mg","ml",1970-01-01,2099-12-31,|'

let $trickyFileContents := 'eapple,Pontius,multiline quotation,date1,date2,usually blank,another crazy multiline,user
pin,Pilatus,"Pilatus ""quoted
 string"" mountain",7/1/1984,7/31/1984,,",a word,
,,and another,,",dcassel'


return
  element csv:csv { local:parseFile($fileContents, fn:true()) }

