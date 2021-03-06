correct-csv-parser-xquery
=========================

Author: Matthew Royal

## OVERVIEW:
This CSV parser correctly parses CSV files with escaped quotation marks ("") and carriage returns in column data. It is probably slower than <a href="https://github.com/dmcassel/blog-code">other parsers</a>, because the XQuery language standard does not support several key Regex features and relies on parsing the file one character at a time instead. 

If your column data contains these escaped characters, to my knowledge this is currently the only XQuery-based CSV-to-XML converter that can parse them properly. If your data contains no such escape sequences, you will get much better performance
using a different parser.


## PERFORMANCE:
Quite a bit of speed was gained by NOT using the fn:substring() method -- instead, the file is converted to a <a href="http://www.xqueryfunctions.com/xq/fn_string-to-codepoints.html">sequence of codepoints</a>. More than likely, the substring method's performance is O(n), so iterating a character at a time has an efficiency of O(n!).

It's still too slow for very large data sets -- using my Macbook Pro (2.3 GHz i7, 16 GB DDR3) running a 7.95MB CSV and writing it to an XML file took PT2M53.663599S

Additional performance gains could be found by eliminating all the xs:string() casting.


## <a href="http://tools.ietf.org/html/rfc4180">RFC 4180</a> GRAMMAR:
```
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
```

Parameters:
```
  $file as xs:string -- contents of CSV file to parse
  $header as xs:boolean -- indicates that the first row of the file is the header.
```
