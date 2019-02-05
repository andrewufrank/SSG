<!DOCTYPE html>
<!-- old  master page for the pandoc templating mechanism includes a body page
	expects body inserted from second template using the glabrous templating mechanis
	needs page-title, page-title-postfix
		author date and keywords for indexing
	uses style.css as default, other can be loaded
	-->
<html lang="$lang$">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes" />

    <link rel="stylesheet" type="text/css" href=static/style.css">

  <style type="text/css">
      code{white-space: pre-wrap;}
      span.smallcaps{font-variant: small-caps;}
      span.underline{text-decoration: underline;}
      div.column{display: inline-block; vertical-align: top; width: 50%;}
	$if(quotes)$
      	q { quotes: "“" "”" "‘" "’"; }
	$endif$
  </style>

	$if(highlighting-css)$
	  <style type="text/css">
	$highlighting-css$
	  </style>
	$endif$

	$for(css)$
	  <link rel="stylesheet" href="$css$" />
	$endfor$

    $for(author)$
      <meta name="author" content="$author$" />
    $endfor$
    $if(date)$
      <meta name="dcterms.date" content="$date$" />
    $endif$
    $if(keywords)$
      <meta name="keywords" content="$for(keywords)$$keywords$$sep$, $endfor$" />
    $endif$

	<title>$page-title$$if(page-title-postfix)$--$page-title-postfix$$endif$</title>
	
<!--    <title>$if(title-prefix)$$title-prefix$ – $endif$$pagetitle$</title>
	$if(math)$
	  $math$
	$endif$
	$for(header-includes)$
	  $header-includes$
	$endfor$
-->

<!-- end master - start page -->

    </head>

    <body>
    <!-- AF - my template for pandoc page (from the default) page3.dtpl -->
        $for(include-before)$
        $include-before$
        $endfor$

        $if(title)$
        <header>
        <h1 class="title">$title$</h1>
        $if(subtitle)$
        <p class="subtitle">$subtitle$</p>
        $endif$

        $for(author)$
        <p class="author">$author$</p>
        $endfor$
        $if(date)$
        <p class="date">$date$</p>
        $endif$
        </header>
        $endif$

    <section class="hero">
            <h1><br><br><a href="/">$settings.sitename$</a></h1>
            <h3>$settings.byline$</h3>
    </section>
    <section class="header">

            <section class="menu">
		<ul>
            	$for(menu)$
				<li><a href=$menu.link$>$menu.text$</a></li>
            		$endfor$
		</ul>
    </section>

<!-- start tufte with article tag -->
    <article>
        $if(contentHtml)$
        $contentTufte$
        $endif$
    </article>
<!-- end article tag from tufte  -->

        $if(toc)$
        <nav id="$idprefix$TOC">
        $table-of-contents$
        </nav>
        $endif$
    <section class="header">
        <h3> $title$ </h3>
        <p> $contentHtml$  </p>
    </section>

    <p class=meta tiny">
        Produced with SGG on $datetime.date.today$.
    </p>

        $for(include-after)$
        $include-after$
        $endfor$
    </body>


</html>
