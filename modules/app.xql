xquery version "3.1";
module namespace app="http://www.digital-archiv.at/ns/templates";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace functx = 'http://www.functx.com';
import module namespace templates="http://exist-db.org/xquery/templates" ;
import module namespace config="http://www.digital-archiv.at/ns/config" at "config.xqm";
import module namespace kwic = "http://exist-db.org/xquery/kwic" at "resource:org/exist/xquery/lib/kwic.xql";


declare variable $app:data := $config:app-root||'/data';
declare variable $app:editions := $config:app-root||'/data/editions';
declare variable $app:texts := $config:app-root||'/data/texts';
declare variable $app:descriptions := $config:app-root||'/data/descriptions';
declare variable $app:indices := $config:app-root||'/data/indices';
declare variable $app:placeIndex := $config:app-root||'/data/indices/listplace.xml';
declare variable $app:personIndex := $config:app-root||'/data/indices/listperson.xml';
declare variable $app:orgIndex := $config:app-root||'/data/indices/listorg.xml';
declare variable $app:workIndex := $config:app-root||'/data/indices/listtitle.xml';
declare variable $app:defaultXsl := doc($config:app-root||'/resources/xslt/xmlToHtml.xsl');

declare function functx:contains-case-insensitive
  ( $arg as xs:string? ,
    $substring as xs:string )  as xs:boolean? {

   contains(upper-case($arg), upper-case($substring))
 } ;

 declare function functx:escape-for-regex
  ( $arg as xs:string? )  as xs:string {

   replace($arg,
           '(\.|\[|\]|\\|\||\-|\^|\$|\?|\*|\+|\{|\}|\(|\))','\\$1')
 } ;

declare function functx:substring-after-last
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {
    replace ($arg,concat('^.*',$delim),'')
 };

 declare function functx:substring-before-last
  ( $arg as xs:string? ,
    $delim as xs:string )  as xs:string {

   if (matches($arg, functx:escape-for-regex($delim)))
   then replace($arg,
            concat('^(.*)', functx:escape-for-regex($delim),'.*'),
            '$1')
   else ''
 } ;

 declare function functx:capitalize-first
  ( $arg as xs:string? )  as xs:string? {

   concat(upper-case(substring($arg,1,1)),
             substring($arg,2))
 } ;

(:~
 : returns the names of the previous, current and next document
:)

declare function app:next-doc($collection as xs:string, $current as xs:string) {
let $all := sort(xmldb:get-child-resources($collection))
let $currentIx := index-of($all, $current)
let $prev := if ($currentIx > 1) then $all[$currentIx - 1] else false()
let $next := if ($currentIx < count($all)) then $all[$currentIx + 1] else false()
return
    ($prev, $current, $next)
};

declare function app:doc-context($collection as xs:string, $current as xs:string) {
let $all := sort(xmldb:get-child-resources($collection))
let $currentIx := index-of($all, $current)
let $prev := if ($currentIx > 1) then $all[$currentIx - 1] else false()
let $next := if ($currentIx < count($all)) then $all[$currentIx + 1] else false()
let $amount := count($all)
return
    ($prev, $current, $next, $amount, $currentIx)
};


declare function app:fetchEntity($ref as xs:string){
    let $entity := collection($config:app-root||'/data/indices')//*[@xml:id=$ref]
    let $type: = if (contains(node-name($entity), 'place')) then 'place'
        else if  (contains(node-name($entity), 'person')) then 'person'
        else 'unkown'
    let $viewName := if($type eq 'place') then(string-join($entity/tei:placeName[1]//text(), ', '))
        else if ($type eq 'person' and exists($entity/tei:persName/tei:forename)) then string-join(($entity/tei:persName/tei:surname/text(), $entity/tei:persName/tei:forename/text()), ', ')
        else if ($type eq 'person') then $entity/tei:placeName/tei:surname/text()
        else 'no name'
    let $viewName := normalize-space($viewName)

    return
        ($viewName, $type, $entity)
};

declare function local:everything2string($entity as node()){
    let $texts := normalize-space(string-join($entity//text(), ' '))
    return
        $texts
};

declare function local:viewName($entity as node()){
    let $name := node-name($entity)
    return
        $name
};


(:~
: returns the name of the document of the node passed to this function.
:)
declare function app:getDocName($node as node()){
let $name := functx:substring-after-last(document-uri(root($node)), '/')
    return $name
};

(:~
: returns the (relativ) name of the collection the passed in node is located at.
:)
declare function app:getColName($node as node()){
let $root := tokenize(document-uri(root($node)), '/')
    let $dirIndex := count($root)-1
    return $root[$dirIndex]
};

(:~
: renders the name element of the passed in entity node as a link to entity's info-modal.
:)
declare function app:nameOfIndexEntry($node as node(), $model as map (*)){

    let $searchkey := xs:string(request:get-parameter("searchkey", "No search key provided"))
    let $withHash:= '#'||$searchkey
    let $entities := collection($app:editions)//tei:TEI//*[@ref=$withHash]
    let $terms := (collection($app:editions)//tei:TEI[.//tei:term[./text() eq substring-after($withHash, '#')]])
    let $noOfterms := count(($entities, $terms))
    let $hit := collection($app:indices)//*[@xml:id=$searchkey]
    let $name := if (contains(node-name($hit), 'person'))
        then
            <a class="reference" data-type="listperson.xml" data-key="{$searchkey}">{normalize-space(string-join($hit/tei:persName[1], ', '))}</a>
        else if (contains(node-name($hit), 'place'))
        then
            <a class="reference" data-type="listplace.xml" data-key="{$searchkey}">{normalize-space(string-join($hit/tei:placeName[1], ', '))}</a>
        else if (contains(node-name($hit), 'org'))
        then
            <a class="reference" data-type="listorg.xml" data-key="{$searchkey}">{normalize-space(string-join($hit/tei:orgName[1], ', '))}</a>
        else if (contains(node-name($hit), 'bibl'))
        then
            <a class="reference" data-type="listwork.xml" data-key="{$searchkey}">{normalize-space(string-join($hit/tei:title[1], ', '))}</a>
        else
            functx:capitalize-first($searchkey)
    return
    <h1 style="text-align:center;">
        <small>
            <span id="hitcount"/>{$noOfterms} Treffer für</small>
        <br/>
        <strong>
            {$name}
        </strong>
    </h1>
};

(:~
 : href to document.
 :)
declare function app:hrefToDoc($node as node()){
let $name := functx:substring-after-last($node, '/')
let $href := concat('../pages/show.html','?document=', app:getDocName($node))
    return $href
};

(:~
 : href to document.
 :)
declare function app:hrefToDoc($node as node(), $collection as xs:string){
let $name := functx:substring-after-last($node, '/')
let $href := concat('../pages/show.html','?document=', app:getDocName($node), '&amp;directory=', $collection)
    return $href
};

(:~
 : a fulltext-search function
 :)
 declare function app:ft_search($node as node(), $model as map (*)) {
 if (request:get-parameter("searchexpr", "") !="") then
 let $searchterm as xs:string:= request:get-parameter("searchexpr", "")
 for $hit in collection(concat($config:app-root, '/data/editions/'))//*[.//tei:p[ft:query(.,$searchterm)]]
    let $href := concat(app:hrefToDoc($hit), "&amp;searchexpr=", $searchterm)
    let $score as xs:float := ft:score($hit)
    order by $score descending
    return
    <tr>
        <td>{$score}</td>
        <td class="KWIC">{kwic:summarize($hit, <config width="40" link="{$href}" />)}</td>
        <td>{app:getDocName($hit)}</td>
    </tr>
 else
    <div>Nothing to search for</div>
 };

declare function app:indexSearch_hits($node as node(), $model as map(*),  $searchkey as xs:string?, $path as xs:string?){
let $indexSerachKey := $searchkey
let $searchkey:= '#'||$searchkey
let $entities := collection($app:data)//tei:TEI[.//*/@ref=$searchkey]
let $terms := collection($app:editions)//tei:TEI[.//tei:term[./text() eq substring-after($searchkey, '#')]]
for $title in ($entities, $terms)
    let $docTitle := string-join(root($title)//tei:titleStmt/tei:title[@type='main']//text(), ' ')
    let $hits := if (count(root($title)//*[@ref=$searchkey]) = 0) then 1 else count(root($title)//*[@ref=$searchkey])
    let $collection := app:getColName($title)
    let $snippet :=
        for $entity in root($title)//*[@ref=$searchkey]
                let $before := $entity/preceding::text()[1]
                let $after := $entity/following::text()[1]
                return
                    <p>… {$before} <strong><a href="{concat(app:hrefToDoc($title, $collection), "&amp;searchkey=", $indexSerachKey)}"> {$entity//text()[not(ancestor::tei:abbr)]}</a></strong> {$after}…<br/></p>
    let $zitat := $title//tei:msIdentifier
    let $collection := app:getColName($title)
    return
            <tr>
               <td>{$docTitle}</td>
               <td>{$hits}</td>
               <td>{$snippet}<p style="text-align:right">{<a href="{concat(app:hrefToDoc($title, $collection), "&amp;searchkey=", $indexSerachKey)}">{app:getDocName($title)}</a>}</p></td>
            </tr>
};

(:~
 : creates a basic person-index derived from the  '/data/indices/listperson.xml'
 :)
declare function app:listPers($node as node(), $model as map(*)) {
    let $hitHtml := "hits.html?searchkey="
    for $person in doc($app:personIndex)//tei:listPerson/tei:person
    let $persName := $person/tei:persName[1]/text()
    let $altnames := string-join(subsequence($person//tei:persName, 2), ' ')
    let $occupation := string-join($person//tei:occupation, ' ')
    let $ref := data($person/tei:persName[1]/@ref)
    let $reflink := if($ref)
        then
            <a href="{$ref}">{$ref}</a>
        else
            "-"

    return
        <tr>
            <td>
                <a href="{concat($hitHtml,data($person/@xml:id))}">{$persName}</a>
            </td>
            <td>
                {$altnames}
            </td>
            <td>{$occupation}</td>
            <td>
                {$reflink}
            </td>
        </tr>
};

(:~
 : creates a basic place-index derived from the  '/data/indices/listplace.xml'
 :)
declare function app:listPlace($node as node(), $model as map(*)) {
    let $hitHtml := "hits.html?searchkey="
    for $place in doc($app:placeIndex)//tei:listPlace/tei:place
    let $geonames := data($place/tei:placeName/@ref)
    let $ref := if ($geonames)
        then
            <a href="{$geonames}">{$geonames}</a>
        else
            "-"
    let $lat := tokenize($place//tei:geo/text(), ' ')[1]
    let $lng := tokenize($place//tei:geo/text(), ' ')[2]
        return
        <tr>
            <td>
                <a href="{concat($hitHtml, data($place/@xml:id))}">{functx:capitalize-first($place/tei:placeName[1])}</a>
            </td>
            <td>{$ref}</td>
            <td>{$lat}</td>
            <td>{$lng}</td>
        </tr>
};

(:~
 : creates a basic table of content derived from the documents stored in '/data/editions'
 :)

declare function app:toctrans($node as node(), $model as map(*)) {

    let $collection := request:get-parameter("collection", "")
    let $docs := if ($collection)
        then
            collection(concat($config:app-root, '/data/', $collection, '/'))//tei:TEI
        else
            collection(concat($config:app-root, '/data/editions/'))//tei:TEI
    for $title in $docs
        let $mstitle := $title//tei:titleStmt/tei:title[1]/text()
        return
        <tr>
           <td>{$mstitle}</td>
            <td><a href="{app:hrefToDoc($title, $collection)}">{app:getDocName($title)}</a></td>
        </tr>
};

(:~
 : creates a basic table of content derived from the documents stored in '/data/descriptions'
 :)
declare function app:tocdesc($node as node(), $model as map(*)) {

    let $collection := request:get-parameter("collection", "")
    let $docs := if ($collection)
        then
            collection(concat($config:app-root, '/data/', $collection, '/'))//tei:TEI
        else
            collection(concat($config:app-root, '/data/editions/'))//tei:TEI
    for $title in $docs
        let $mstitle := $title//tei:title[@type='sub']/text()
        let $link2doc := if ($collection)
            then
                <a href="{app:hrefToDoc($title, $collection)}">{$mstitle}</a>
            else
                <a href="{app:hrefToDoc($title)}">{$mstitle}</a>
        let $head := $title//tei:head[1]
        let $origtitle := $title//tei:head[1]/tei:title/text()
        let $from := data($head/tei:origDate/@notBefore)
        let $to := data($head/tei:origDate/@notAfter)
        let $origpl := $head/tei:origPlace/text()
        let $settl := $title//tei:settlement[1]/text()
        let $lib := $title//tei:repository[1]/text()
        let $aratea : = for $x in $title//tei:note[@type="aratea"]/tei:rs
            let $href := substring-after(data($x/@ref), '#')
            let $link := "show.html?document="||$href||"&amp;directory=texts"
            return <li><a href="{$link}">{$x}</a></li>
        return
        <tr>
           <td>{$link2doc}</td>
            <td>
                {$origtitle}
            </td>
            <td>{$aratea}</td>
            <td>{count($aratea)}</td>
            <td>
                {$from}
            </td>
            <td>{$to}</td>
            <td>{$origpl}</td>
            <td>{$lib} ({$settl})</td>
            <td>{app:getDocName($title)}</td>
        </tr>
};

(:~
 : creates a basic table of content derived from the documents stored in '/data/texts'
 :)
declare function app:toctext($node as node(), $model as map(*)) {

    let $collection := request:get-parameter("collection", "")
    let $docs := if ($collection)
        then
            collection(concat($config:app-root, '/data/', $collection, '/'))//tei:TEI
        else
            collection(concat($config:app-root, '/data/editions/'))//tei:TEI
    for $title in $docs
        let $mstitle := $title//tei:titleStmt/tei:title[1]/text()
        let $link2doc := if ($collection)
            then
                <a href="{app:hrefToDoc($title, $collection)}">{$mstitle}</a>
            else
                <a href="{app:hrefToDoc($title)}">{$mstitle}</a>
        let $mscount := count($title//tei:item)
        return
        <tr>
           <td>{$link2doc}</td>
            <td>
                {$mscount}
            </td>
            <td>{app:getDocName($title)}</td>
        </tr>
};

(:~
 : creates a basic table of content derived from the documents stored in '/data/transcriptions'
 :)
declare function app:toctrans($node as node(), $model as map(*)) {

    let $collection := request:get-parameter("collection", "")
    let $docs := if ($collection)
        then
            collection(concat($config:app-root, '/data/', $collection, '/'))//tei:TEI
        else
            collection(concat($config:app-root, '/data/editions/'))//tei:TEI
    for $title in $docs
        let $mstitle := $title//tei:titleStmt/tei:title[1]/text()
        return
        <tr>
           <td>{$mstitle}</td>
            <td><a href="{app:hrefToDoc($title, $collection)}">{app:getDocName($title)}</a></td>
        </tr>
};

(:~
 : perfoms an XSLT transformation
:)
declare function app:XMLtoHTML ($node as node(), $model as map (*), $query as xs:string?) {
let $ref := xs:string(request:get-parameter("document", ""))
let $refname := substring-before($ref, '.xml')
let $xmlPath := concat(xs:string(request:get-parameter("directory", "editions")), '/')
let $xml := doc(replace(concat($config:app-root,'/data/', $xmlPath, $ref), '/exist/', '/db/'))
let $collectionName := util:collection-name($xml)
let $collection := functx:substring-after-last($collectionName, '/')
let $neighbors := app:doc-context($collectionName, $ref)
let $prev := if($neighbors[1]) then 'show.html?document='||$neighbors[1]||'&amp;directory='||$collection else ()
let $next := if($neighbors[3]) then 'show.html?document='||$neighbors[3]||'&amp;directory='||$collection else ()
let $amount := $neighbors[4]
let $currentIx := $neighbors[5]
let $progress := ($currentIx div $amount)*100
let $xslPath := xs:string(request:get-parameter("stylesheet", ""))
let $xsl := if($xslPath eq "")
    then
        if(doc($config:app-root||'/resources/xslt/'||$collection||'.xsl'))
            then
                doc($config:app-root||'/resources/xslt/'||$collection||'.xsl')
        else if(doc($config:app-root||'/resources/xslt/'||$refname||'.xsl'))
            then
                doc($config:app-root||'/resources/xslt/'||$refname||'.xsl')
        else
            $app:defaultXsl
    else
        if(doc($config:app-root||'/resources/xslt/'||$xslPath||'.xsl'))
            then
                doc($config:app-root||'/resources/xslt/'||$xslPath||'.xsl')
            else
                $app:defaultXsl
let $path2source := "../resolver/resolve-doc.xql?doc-name="||$ref||"&amp;collection="||$collection
let $params :=
<parameters>
    <param name="app-name" value="{$config:app-name}"/>
    <param name="collection-name" value="{$collection}"/>
    <param name="path2source" value="{$path2source}"/>
    <param name="prev" value="{$prev}"/>
    <param name="next" value="{$next}"/>
    <param name="amount" value="{$amount}"/>
    <param name="currentIx" value="{$currentIx}"/>
    <param name="progress" value="{$progress}"/>

   {
        for $p in request:get-parameter-names()
            let $val := request:get-parameter($p,())
                return
                   <param name="{$p}"  value="{$val}"/>
   }
</parameters>
return
    transform:transform($xml, $xsl, $params)
};

(:~
 : creates a basic work-index derived from the  '/data/indices/listbibl.xml'
 :)
declare function app:listBibl($node as node(), $model as map(*)) {
    let $hitHtml := "hits.html?searchkey="
    for $item in doc($app:workIndex)//tei:listBibl/tei:bibl
    let $author := normalize-space(string-join($item/tei:author//text(), ' '))
    let $gnd := $item//tei:idno/text()
    let $gnd_link := if ($gnd)
        then
            <a href="{$gnd}">{$gnd}</a>
        else
            'no normdata provided'
   return
        <tr>
            <td>
                <a href="{concat($hitHtml,data($item/@xml:id))}">{$item//tei:title[1]/text()}</a>
            </td>
            <td>
                {$author}
            </td>
            <td>
                {$gnd_link}
            </td>
        </tr>
};

(:~
 : creates a basic organisation-index derived from the  '/data/indices/listorg.xml'
 :)
declare function app:listOrg($node as node(), $model as map(*)) {
    let $hitHtml := "hits.html?searchkey="
    for $item in doc($app:orgIndex)//tei:listOrg/tei:org
        let $gnd := data($item/tei:orgName/@ref)
        let $gnd_link := if($gnd)
            then
                <a href="{$gnd}">{$gnd}</a>
            else
                "-"
        return
        <tr>
            <td>
                <a href="{concat($hitHtml,data($item/@xml:id))}">{$item//tei:orgName[1]/text()}</a>
            </td>
            <td>{$gnd_link}</td>
        </tr>
};

(:~
 : fetches the first document in the given collection
 :)
declare function app:firstDoc($node as node(), $model as map(*)) {
    let $all := sort(xmldb:get-child-resources($app:editions))
    let $href := "show.html?document="||$all[1]||"&amp;directory=editions"
        return
            <a class="btn btn-main btn-outline-primary btn-lg" href="{$href}" role="button">Start Reading</a>
};
