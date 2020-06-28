# BibleDownloader
This function contains a GUI that wraps download scripts for several Bible translations. This involves downloading publicly available web pages and then stripping the html or json files down to only the Bible text itself. This is then written to a UTF8 text file. This function can also run with the free 'mostly Matlab-compatible program' Octave (version 4.2.1).

The creation of this function was motivated by the research into readability of Dutch Bible translations, which I did when writing a book together with a friend. This book ('Door de bomen van het Bijbelwoud') now has an accompanying website: https://www.bijbelwoud.nl

Available Bible translations:\
  English:\
ASV: American Standard Version\
KJV: King James Version\
NASB: New American Standard Version\
WEB: World English Bible\
  French:\
LS1910: Luis Segond (1910)\
  Spanish:\
RV1602: Reina Valera (1602)\
  Dutch:\
BB: de Basisbijbel\
BGT: de Bijbel in Gewone Taal\
GNB: Groot Nieuws Bijbel\
HB: Het Boek\
HSV: de Herziene Statenvertaling\
NB: de Naardense Bijbel\
NBG51: de Nieuwe Vertaling (1951)\
NBV: de Nieuwe Bijbelvertaling\
NWv2004: de Nieuwe-Wereldvertaling (2004)\
NWv2017: de Nieuwe Wereldvertaling (2017)\
SV1637: de Statenvertaling (1637, original version)\
SV1750: de Statenvertaling (1750)\
SV73: de Statenvertaling (1973, revision by the GBS)\
SV77: de Statenvertaling (1977, revisie by the NBG)\
WV75: de Willibrordvertaling\

---- Disclaimer: ---- \
Under Dutch law, downloading a copy of a copyright protected work is allowed if you are a natural person (i.e. a human, and not acting for a corporation) and the copy is for personal (home) use only, under the condition that you already own an otherwise legally acquired copy. Adding the file mentioned below to the main folder means you have read this disclaimer, agree to it, and assume full legal responsibility for the use of this script and the files it generates.
WARNING: The law of your jurisdiction might be different. It may prohibit the use of this script or set different requirements.
You must agree to these requirements by creating a file with this name (in the same folder as this function):
'I hereby declare I will only use this script if and only if it is legal for me to do so.txt'
If you do not create this file, you will only be able to download public domain translation.  
---- /Disclaimer ----

This submission uses a selection of scripts from JSONlab.

For a description of the .bible file format, see the included help text.

Sources:\
(The URL for Genesis 1 is given for each translation. See the code itself for more details about the pattern for each translation.)\
ASV:\
https://www.bible.com/bible/12/GEN.1.asv  
KJV:  
https://www.bible.com/bible/1/GEN.1.kjv  
NASB:  
https://www.bible.com/bible/100/GEN.1.nasb  
WEB:  
https://www.bible.com/bible/206/GEN.1.web  
LS1910:  
https://www.bible.com/bible/93/GEN.1.lsg  
RV1602:  
https://www.bible.com/bible/147/GEN.1.rves  
BB:  
https://www.basisbijbel.nl/boek/genesis/1  
BGT:  
https://www.debijbel.nl/api/bible/passage?identifier=GEN1&language=nl&version=nld-BGT  
GNB:  
http://grootnieuwsbijbel.wordpress.com/gen1  
HB:  
https://www.bible.com/nl/bible/75/GEN.1.htb  
HSV:  
https://herzienestatenvertaling.nl/teksten/genesis/1/  
NB:  
http://www.naardensebijbel.nl/page/1/?search-class=DB_CustomSearch_Widget-db_customsearch_widget&widget_number=preset-default&-0=vers&cs-booknr-1=1&cs-bijbelhoofdstuk-2=1&cs-versnummer-3=&cs-bijbelvers_v2-4=&search=Zoeken  
NBG51:  
https://www.bible.com/bible/328/GEN.1.ngb51  
NBV:  
https://www.debijbel.nl/api/bible/passage?identifier=GEN1&language=nl&version=nld-NBV  
NWv2004:  
http://www.jw.org/nl/publicaties/bijbel/bi12/boeken/GENESIS/1/  
NWv2017:  
http://www.jw.org/nl/publicaties/bijbel/nwt/boeken/GENESIS/1/  
SV1637:  
http://www.bijbelsdigitaal.nl/view/?mode=3&bible=sv1637&bible2=sv1977&ref=GEN.1  
SV1750:  
https://www.bible.com/bible/165/GEN.1.sv1750  
SV73:  
http://statenvertaling.nl/tekst.php?bb=1&hf=1&ind=3  
SV77:  
http://www.bijbelsdigitaal.nl/view/?mode=3&bible=sv1637&bible2=sv1977&ref=GEN.1  
WV75:  
http://www.rkdocumenten.nl/rkdocs/index.php?mi=600&doc=5061&id=7829
