# Fragenkatalog für alle 2-gegen-2-Spiele (Quizduell, Schätzduell,
# Emoji-Rätsel, Seelenverwandt). Erzeugt assets/quiz/questions.json
# (Demo/Tests) und SQL-Seeds.
#
# IDs entstehen aus der Reihenfolge hier. Deshalb: Bestehendes nie umsortieren
# oder löschen, Neues nur hinten anhängen und als NEUE Migration erzeugen:
#   python3 tool/quiz_questions.py supabase/migrations/<zeit>_x.sql --since-id <alte max. ID>
#
# Quizduell:      Frage, richtige Antwort, 3 falsche
# Emoji-Rätsel:   Emoji-Folge, richtige Antwort, 3 falsche
# Schätzduell:    Frage, Zahl, Einheit
# Seelenverwandt: Frage, 2–4 Antwortmöglichkeiten (keine ist „richtig“)
CATEGORIES = [
 ("allgemein","🧠","Allgemeinwissen"),("geografie","🌍","Geografie"),("geschichte","🏛️","Geschichte"),
 ("wissenschaft","🔬","Wissenschaft"),("natur","🐾","Tiere & Natur"),("sport","⚽","Sport"),
 ("musik","🎵","Musik"),("film","🎬","Film & Serien"),("gaming","🎮","Gaming"),
 ("essen","🍝","Essen & Trinken"),("sprache","📚","Sprache & Literatur"),("technik","💻","Technik & Internet"),
 ("liebe","💘","Liebe & Dating"),
]
Q = {
"allgemein": [
 ("Wie viele Tage hat ein Schaltjahr?", "366","365","364","367"),
 ("Wie viele Minuten hat ein Tag?", "1440","1240","1600","1200"),
 ("Welche Farbe ergibt sich aus Blau und Gelb?", "Grün","Lila","Orange","Braun"),
 ("Wie viele Seiten hat ein Sechseck?", "6","5","7","8"),
 ("Was misst ein Barometer?", "Luftdruck","Temperatur","Luftfeuchtigkeit","Windgeschwindigkeit"),
 ("Wie heißt die Hauptstadt von Australien?", "Canberra","Sydney","Melbourne","Perth"),
 ("Wie viele Spieler einer Mannschaft stehen beim Fußball auf dem Feld?", "11","10","12","9"),
 ("Welches Tier ist das Wappentier Deutschlands?", "Adler","Löwe","Bär","Hirsch"),
 ("Wie viele Kontinente gibt es nach gängiger Zählung?", "7","5","6","8"),
 ("Was ist die römische Zahl für 50?", "L","C","D","X"),
 ("Wie viele Karten hat ein klassisches Skatblatt?", "32","52","36","24"),
 ("In welcher Einheit wird elektrische Spannung gemessen?", "Volt","Ampere","Watt","Ohm"),
 ("Wie viele Zähne hat ein erwachsener Mensch normalerweise (inkl. Weisheitszähne)?", "32","28","30","36"),
],
"geografie": [
 ("Welcher Fluss fließt durch Hamburg?", "Elbe","Weser","Rhein","Oder"),
 ("Wie heißt der höchste Berg Deutschlands?", "Zugspitze","Watzmann","Feldberg","Brocken"),
 ("Welches Land hat die meisten Einwohner?", "Indien","China","USA","Indonesien"),
 ("Welcher Ozean ist der größte?", "Pazifik","Atlantik","Indischer Ozean","Arktischer Ozean"),
 ("Wie heißt die Hauptstadt von Kanada?", "Ottawa","Toronto","Vancouver","Montreal"),
 ("In welchem Land liegt Machu Picchu?", "Peru","Bolivien","Chile","Mexiko"),
 ("Welches ist das flächenmäßig größte Land der Erde?", "Russland","Kanada","China","USA"),
 ("Wie viele Bundesländer hat Deutschland?", "16","15","12","18"),
 ("An welchem Fluss liegt Köln?", "Rhein","Main","Mosel","Ruhr"),
 ("Welche Stadt ist die Hauptstadt von Spanien?", "Madrid","Barcelona","Sevilla","Valencia"),
 ("Auf welchem Kontinent liegt die Sahara?", "Afrika","Asien","Australien","Südamerika"),
 ("Welches Meer liegt zwischen Europa und Afrika?", "Mittelmeer","Schwarzes Meer","Rotes Meer","Ostsee"),
 ("Welches Land hat die Form eines Stiefels?", "Italien","Griechenland","Portugal","Kroatien"),
],
"geschichte": [
 ("In welchem Jahr fiel die Berliner Mauer?", "1989","1990","1987","1991"),
 ("Wer war der erste Bundeskanzler der Bundesrepublik Deutschland?", "Konrad Adenauer","Willy Brandt","Ludwig Erhard","Helmut Schmidt"),
 ("In welchem Jahr landeten Menschen zum ersten Mal auf dem Mond?", "1969","1965","1972","1959"),
 ("Wer erfand den Buchdruck mit beweglichen Lettern in Europa?", "Johannes Gutenberg","Martin Luther","Leonardo da Vinci","Albrecht Dürer"),
 ("In welchem Jahr begann der Erste Weltkrieg?", "1914","1912","1918","1939"),
 ("Wie hieß die erste Frau, die den Nobelpreis erhielt?", "Marie Curie","Ada Lovelace","Florence Nightingale","Bertha von Suttner"),
 ("In welchem Jahr wurde die Deutsche Einheit vollzogen?", "1990","1989","1991","1992"),
 ("Wer schlug 1517 der Überlieferung nach seine Thesen an?", "Martin Luther","Johannes Calvin","Thomas Müntzer","Huldrych Zwingli"),
 ("Welches Schiff sank 1912 auf seiner Jungfernfahrt?", "Titanic","Lusitania","Bismarck","Queen Mary"),
 ("Wer war der erste Kaiser Roms?", "Augustus","Julius Caesar","Nero","Caligula"),
 ("In welchem Jahr endete der Zweite Weltkrieg in Europa?", "1945","1944","1946","1943"),
 ("Welche Stadt war Hauptstadt der Bundesrepublik vor Berlin?", "Bonn","Frankfurt am Main","Köln","München"),
 ("Wie hieß der erste Mensch im Weltall?", "Juri Gagarin","Neil Armstrong","John Glenn","Alexei Leonow"),
],
"wissenschaft": [
 ("Was ist das chemische Symbol für Gold?", "Au","Ag","Go","Gd"),
 ("Welcher Planet ist der Sonne am nächsten?", "Merkur","Venus","Mars","Erde"),
 ("Wie viele Knochen hat ein erwachsener Mensch ungefähr?", "206","180","250","312"),
 ("Bei wie viel Grad Celsius siedet Wasser auf Meereshöhe?", "100","90","110","120"),
 ("Was ist H₂O?", "Wasser","Wasserstoffperoxid","Salz","Sauerstoff"),
 ("Welcher ist der größte Planet unseres Sonnensystems?", "Jupiter","Saturn","Neptun","Uranus"),
 ("Wie heißt das Kraftwerk der Zelle?", "Mitochondrium","Zellkern","Ribosom","Vakuole"),
 ("Welches Gas atmen Pflanzen bei der Photosynthese hauptsächlich ein?", "Kohlendioxid","Sauerstoff","Stickstoff","Helium"),
 ("Wer formulierte die Relativitätstheorie?", "Albert Einstein","Isaac Newton","Max Planck","Niels Bohr"),
 ("Was ist das häufigste Gas in der Erdatmosphäre?", "Stickstoff","Sauerstoff","Kohlendioxid","Argon"),
 ("Wie schnell ist Licht im Vakuum ungefähr?", "300.000 km/s","30.000 km/s","3.000 km/s","3 Mio. km/s"),
 ("Welches Organ produziert Insulin?", "Bauchspeicheldrüse","Leber","Niere","Milz"),
 ("Wie viele Chromosomen hat ein Mensch normalerweise?", "46","23","44","48"),
],
"natur": [
 ("Welches ist das größte Säugetier der Erde?", "Blauwal","Afrikanischer Elefant","Pottwal","Giraffe"),
 ("Wie viele Beine hat eine Spinne?", "8","6","10","12"),
 ("Welches Tier ist das schnellste Landtier?", "Gepard","Löwe","Antilope","Windhund"),
 ("Was frisst ein Großer Panda hauptsächlich?", "Bambus","Fisch","Beeren","Insekten"),
 ("Wie nennt man ein junges Pferd?", "Fohlen","Kalb","Lamm","Ferkel"),
 ("Welcher Vogel kann rückwärts fliegen?", "Kolibri","Spatz","Schwalbe","Specht"),
 ("Wie viele Herzen hat ein Oktopus?", "3","1","2","4"),
 ("Welches Tier hält Winterschlaf?", "Igel","Eichhörnchen","Fuchs","Reh"),
 ("Zu welcher Tiergruppe gehört der Wal?", "Säugetiere","Fische","Reptilien","Amphibien"),
 ("Welcher Baum trägt Eicheln?", "Eiche","Buche","Linde","Ahorn"),
 ("Was ist die Hauptnahrung von Koalas?", "Eukalyptusblätter","Bambus","Gras","Insekten"),
 ("Wie heißt das männliche Huhn?", "Hahn","Kapaun","Erpel","Ganter"),
 ("Welche Farbe hat die Zunge einer Giraffe?", "Dunkelblau bis schwarz","Rosa","Rot","Gelb"),
],
"sport": [
 ("Wie oft wurde Deutschland (Herren) Fußball-Weltmeister?", "4","3","5","2"),
 ("Wie lang ist ein Marathon?", "42,195 km","40 km","42 km","45,5 km"),
 ("In welcher Sportart gibt es einen 'Slam Dunk'?", "Basketball","Volleyball","Tennis","Handball"),
 ("Wie viele Ringe hat das olympische Symbol?", "5","4","6","7"),
 ("Wie viele Punkte ist ein Touchdown im American Football wert?", "6","7","3","5"),
 ("Auf welchem Belag wird das Tennisturnier in Wimbledon gespielt?", "Rasen","Sand","Hartplatz","Teppich"),
 ("Wie viele Spieler hat eine Volleyballmannschaft auf dem Feld?", "6","5","7","8"),
 ("In welcher Stadt fanden die Olympischen Sommerspiele 1972 statt?", "München","Berlin","Montreal","Moskau"),
 ("Wie viele Punkte sind beim Darts mit drei Pfeilen maximal möglich?", "180","150","200","170"),
 ("Wie viele Löcher hat eine Standard-Golfrunde?", "18","9","12","24"),
 ("Wie hoch ist ein Basketballkorb (Ringhöhe)?", "3,05 m","2,85 m","3,25 m","2,95 m"),
 ("Welche Farbe hat das Trikot des Führenden der Tour de France?", "Gelb","Grün","Rot","Weiß-rot gepunktet"),
 ("Wie viele Minuten dauert ein reguläres Fußballspiel?", "90","80","100","120"),
],
"musik": [
 ("Wie viele Saiten hat eine Standardgitarre?", "6","4","5","7"),
 ("Wer komponierte 'Für Elise'?", "Ludwig van Beethoven","Wolfgang Amadeus Mozart","Johann Sebastian Bach","Frédéric Chopin"),
 ("Wie viele Tasten hat ein klassisches Klavier?", "88","76","92","64"),
 ("Aus welchem Land stammt die Band ABBA?", "Schweden","Norwegen","Dänemark","Finnland"),
 ("Welches Instrument spielte Jimi Hendrix hauptsächlich?", "E-Gitarre","Schlagzeug","Saxofon","Bass"),
 ("Wie viele Linien hat ein Notensystem?", "5","4","6","7"),
 ("Wie nennt man die Lautstärkeangabe 'sehr leise'?", "Pianissimo","Fortissimo","Allegro","Crescendo"),
 ("Wie hieß der Sänger der Band Queen?", "Freddie Mercury","Brian May","Mick Jagger","David Bowie"),
 ("Aus welcher Stadt stammten die Beatles?", "Liverpool","London","Manchester","Birmingham"),
 ("Welches Tempo ist schneller?", "Presto","Andante","Adagio","Largo"),
 ("Wer gilt als 'King of Pop'?", "Michael Jackson","Elvis Presley","Prince","Justin Timberlake"),
 ("Wie viele Töne hat eine Dur-Tonleiter innerhalb einer Oktave (ohne Wiederholung des Grundtons)?", "7","8","5","12"),
 ("Aus welchem Land stammt der Tango?", "Argentinien","Spanien","Brasilien","Kuba"),
],
"film": [
 ("Wie heißt der Zauberer-Schüler mit der blitzförmigen Narbe?", "Harry Potter","Frodo Beutlin","Percy Jackson","Merlin"),
 ("Welcher Film gewann bei der Oscarverleihung 1998 als bester Film?", "Titanic","Good Will Hunting","L.A. Confidential","Der Soldat James Ryan"),
 ("Wie heißt der Erzschurke in 'Star Wars – Episode IV'?", "Darth Vader","Darth Maul","Count Dooku","Kylo Ren"),
 ("In welcher Serie kocht ein Chemielehrer Crystal Meth?", "Breaking Bad","Ozark","Narcos","The Wire"),
 ("Welche Stadt ist Schauplatz der Serie 'Friends'?", "New York","Los Angeles","Chicago","Boston"),
 ("Wer spielte Jack Sparrow in 'Fluch der Karibik'?", "Johnny Depp","Orlando Bloom","Brad Pitt","Keanu Reeves"),
 ("Wie heißt der Ring-Träger in 'Der Herr der Ringe'?", "Frodo","Sam","Aragorn","Gandalf"),
 ("Aus welchem Land stammt die Serie 'Dark'?", "Deutschland","Dänemark","Schweden","Österreich"),
 ("Welches Tier ist Simba in 'Der König der Löwen'?", "Löwe","Tiger","Gepard","Leopard"),
 ("Wie heißt die Stadt, in der die Simpsons leben?", "Springfield","Shelbyville","Quahog","South Park"),
 ("Welcher Regisseur drehte 'Pulp Fiction'?", "Quentin Tarantino","Martin Scorsese","Steven Spielberg","Christopher Nolan"),
 ("Wie heißt der Erste Detektiv der 'Drei ???'?", "Justus Jonas","Peter Shaw","Bob Andrews","Kalle Blomquist"),
 ("In welcher Serie gibt es das 'Upside Down'?", "Stranger Things","Lost","The OA","Black Mirror"),
],
"gaming": [
 ("Wie heißt der Klempner, der Prinzessin Peach rettet?", "Mario","Luigi","Wario","Toad"),
 ("Welche Firma entwickelte die PlayStation?", "Sony","Nintendo","Microsoft","Sega"),
 ("Wie heißt das Spiel, in dem man aus Blöcken Welten baut und Creeper explodieren?", "Minecraft","Terraria","Roblox","Fortnite"),
 ("Welche Farbe hat Pac-Man?", "Gelb","Rot","Blau","Grün"),
 ("Wie heißt der Held der 'The Legend of Zelda'-Reihe?", "Link","Zelda","Ganon","Navi"),
 ("Aus welchem Jahr stammt das Spiel 'Tetris' ursprünglich?", "1984","1979","1990","1995"),
 ("Welches Pokémon ist das Maskottchen der Reihe?", "Pikachu","Glumanda","Evoli","Mewtu"),
 ("Wie heißt Microsofts Spielekonsole?", "Xbox","GameCube","Dreamcast","Switch"),
 ("In welchem Spiel kämpfen 100 Spieler auf einer Insel und bauen Festungen?", "Fortnite","Apex Legends","PUBG","Overwatch"),
 ("Wie heißt der blaue Igel von Sega?", "Sonic","Knuckles","Tails","Shadow"),
 ("Welche Konsole brachte Nintendo 2017 heraus?", "Switch","Wii U","GameCube","3DS"),
 ("Wie heißt die Spielfigur in 'Tomb Raider'?", "Lara Croft","Jill Valentine","Samus Aran","Chun-Li"),
 ("Welches Genre ist 'Stardew Valley'?", "Farmsimulation","Ego-Shooter","Rennspiel","Kampfspiel"),
],
"essen": [
 ("Aus welchem Land stammt die Pizza Margherita?", "Italien","Griechenland","Spanien","Frankreich"),
 ("Was ist die Hauptzutat von Guacamole?", "Avocado","Erbse","Gurke","Zucchini"),
 ("Aus welcher Pflanze wird Tequila hergestellt?", "Agave","Zuckerrohr","Kaktusfeige","Mais"),
 ("Was ist Tofu hauptsächlich?", "Sojabohnen","Reis","Weizen","Kichererbsen"),
 ("Welches Gewürz ist das teuerste der Welt?", "Safran","Vanille","Zimt","Kardamom"),
 ("Was ist die Hauptzutat von Hummus?", "Kichererbsen","Linsen","Bohnen","Erbsen"),
 ("Aus welchem Land stammt Sushi?", "Japan","China","Korea","Thailand"),
 ("Welches Getränk wird aus Hopfen und Malz gebraut?", "Bier","Wein","Whisky","Sake"),
 ("Welche Nuss ist die Hauptzutat von Marzipan?", "Mandel","Haselnuss","Walnuss","Cashew"),
 ("Aus welchem Land stammt die Paella?", "Spanien","Portugal","Italien","Mexiko"),
 ("Welche Frucht wächst an einer Palme und hat 'Wasser' im Inneren?", "Kokosnuss","Mango","Ananas","Dattel"),
 ("Wie heißt das italienische Dessert mit Löffelbiskuits und Mascarpone?", "Tiramisu","Panna cotta","Cannoli","Zabaione"),
 ("Was ist Mozzarella traditionell?", "Käse","Wurst","Nudel","Brot"),
],
"sprache": [
 ("Wer schrieb 'Faust'?", "Johann Wolfgang von Goethe","Friedrich Schiller","Heinrich Heine","Thomas Mann"),
 ("Wie viele Buchstaben hat das deutsche Alphabet (ohne Umlaute und ß)?", "26","24","28","30"),
 ("Wer schrieb 'Romeo und Julia'?", "William Shakespeare","Charles Dickens","Oscar Wilde","Jane Austen"),
 ("Was ist ein Palindrom?", "Ein Wort, das rückwärts gleich lautet","Ein Wort mit drei Silben","Ein Fremdwort aus dem Griechischen","Ein Reim am Zeilenende"),
 ("Welche Sprache hat weltweit die meisten Muttersprachler?", "Chinesisch (Mandarin)","Englisch","Spanisch","Hindi"),
 ("Wer schrieb 'Die Verwandlung'?", "Franz Kafka","Hermann Hesse","Thomas Mann","Bertolt Brecht"),
 ("Welche Wortart ist 'schnell'?", "Adjektiv","Verb","Nomen","Präposition"),
 ("Wer erfand die Figur Sherlock Holmes?", "Arthur Conan Doyle","Agatha Christie","Edgar Allan Poe","Charles Dickens"),
 ("Was bedeutet 'Carpe diem'?", "Nutze den Tag","Gute Nacht","Liebe siegt","Alles fließt"),
 ("Wer schrieb 'Harry Potter'?", "J. K. Rowling","J. R. R. Tolkien","Cornelia Funke","Suzanne Collins"),
 ("Wie nennt man ein Wort mit gegenteiliger Bedeutung?", "Antonym","Synonym","Homonym","Akronym"),
 ("Wer schrieb 'Die Räuber'?", "Friedrich Schiller","Gotthold Ephraim Lessing","Goethe","Heinrich von Kleist"),
 ("In welcher Sprache wurde 'Der kleine Prinz' ursprünglich geschrieben?", "Französisch","Deutsch","Englisch","Italienisch"),
],
"technik": [
 ("Wofür steht 'WWW'?", "World Wide Web","Wide World Web","World Web Wide","Web World Wide"),
 ("Wer gründete Microsoft zusammen mit Paul Allen?", "Bill Gates","Steve Jobs","Mark Zuckerberg","Larry Page"),
 ("Wie viele Bit hat ein Byte?", "8","4","16","10"),
 ("Was bedeutet 'CPU'?", "Central Processing Unit","Computer Power Unit","Central Program Utility","Core Processing Unit"),
 ("In welchem Jahr kam das erste iPhone auf den Markt?", "2007","2005","2009","2010"),
 ("Welche Programmiersprache ist nach einer Komikergruppe benannt?", "Python","Java","Ruby","Swift"),
 ("Was ist ein 'Captcha'?", "Ein Test, ob ein Mensch vor dem Gerät sitzt","Ein Computervirus","Ein Speicherformat","Eine Tastenkombination"),
 ("Wofür steht 'USB'?", "Universal Serial Bus","Unified System Board","Universal Storage Box","User Service Bus"),
 ("Welches Unternehmen entwickelt das Betriebssystem Android hauptsächlich?", "Google","Apple","Samsung","Microsoft"),
 ("Was ist die Hauptaufgabe eines Routers?", "Datenpakete zwischen Netzwerken weiterleiten","Strom speichern","Dateien drucken","Bilder bearbeiten"),
 ("Wie heißt die Maßeinheit für Frequenz?", "Hertz","Watt","Joule","Tesla"),
 ("Was bedeutet das 'S' in 'HTTPS'?", "Secure","Simple","Server","Speed"),
 ("Wer gilt als erste Programmiererin der Welt?", "Ada Lovelace","Grace Hopper","Marie Curie","Hedy Lamarr"),
],
"liebe": [
 ("An welchem Tag ist Valentinstag?", "14. Februar","14. März","1. Mai","24. Februar"),
 ("Welche Blume gilt als Symbol der Liebe?", "Rote Rose","Tulpe","Sonnenblume","Lilie"),
 ("Wie heißt der römische Liebesgott mit Pfeil und Bogen?", "Amor","Mars","Merkur","Bacchus"),
 ("Wie viele Jahre feiert man bei der 'Silberhochzeit'?", "25","10","40","50"),
 ("Wie heißt das Liebespaar aus Veronas berühmtestem Drama?", "Romeo und Julia","Tristan und Isolde","Orpheus und Eurydike","Bonnie und Clyde"),
 ("Wie nennt man die 'Goldene Hochzeit' in Jahren?", "50","25","60","75"),
 ("Welches Hormon wird oft 'Kuschelhormon' genannt?", "Oxytocin","Adrenalin","Cortisol","Melatonin"),
 ("In welcher Stadt hängten Verliebte bis 2015 Tausende Schlösser an die Brücke Pont des Arts?", "Paris","Rom","Venedig","Prag"),
 ("Wie heißt die griechische Göttin der Liebe?", "Aphrodite","Athene","Hera","Artemis"),
 ("Welche Farbe steht traditionell für Treue?", "Blau","Rot","Gelb","Grün"),
 ("Wie nennt man es, wenn sich jemand plötzlich ohne Erklärung nicht mehr meldet?", "Ghosting","Benching","Breadcrumbing","Catfishing"),
 ("Welches Edelmetall ist bei Eheringen in Deutschland am verbreitetsten?", "Gold","Silber","Platin","Titan"),
 ("Wie nennt man es, wenn jemand online mit einem falschen Profil auftritt?", "Catfishing","Ghosting","Orbiting","Love Bombing"),
],
}


# Schätzduell: (Frage, richtige Zahl, Einheit). Einheit „Jahr“ wird nach
# Jahren statt prozentual gewertet.
ESTIMATE_CATEGORIES = [
 ("est_geo","🌍","Erde & Länder"),("est_bau","🏗️","Bauwerke"),("est_jahr","📅","Jahreszahlen"),
 ("est_koerper","🫀","Mensch & Körper"),("est_tiere","🐘","Tierisch"),("est_alltag","🧮","Alltag in Zahlen"),
]
ESTIMATE = {
"est_geo": [
 ("Wie hoch ist der Mount Everest?", 8849, "m"),
 ("Wie lang ist der Rhein insgesamt?", 1233, "km"),
 ("Wie viele Einwohner hat Deutschland ungefähr (in Millionen)?", 84, "Mio."),
 ("Wie groß ist die Fläche Deutschlands?", 357600, "km²"),
 ("Wie hoch ist die Zugspitze?", 2962, "m"),
 ("Wie weit ist es Luftlinie von Berlin nach München?", 504, "km"),
 ("Wie tief ist der Bodensee an seiner tiefsten Stelle?", 251, "m"),
 ("Wie viele Mitgliedsstaaten hat die EU?", 27, "Länder"),
 ("Wie hoch ist der Brocken im Harz?", 1141, "m"),
],
"est_bau": [
 ("Wie hoch ist der Eiffelturm (mit Antennen)?", 330, "m"),
 ("Wie hoch ist der Burj Khalifa in Dubai?", 828, "m"),
 ("Wie hoch ist der Kölner Dom?", 157, "m"),
 ("Wie hoch ist der Berliner Fernsehturm?", 368, "m"),
 ("Wie hoch ist die Freiheitsstatue mit Sockel?", 93, "m"),
 ("Wie weit liegen die beiden Türme der Golden Gate Bridge auseinander?", 1280, "m"),
 ("Wie hoch ist die Cheops-Pyramide heute?", 139, "m"),
 ("Wie hoch ist der Turm mit dem Big Ben in London?", 96, "m"),
 ("Wie hoch ist das Empire State Building mit Antenne?", 443, "m"),
],
"est_jahr": [
 ("In welchem Jahr erreichte Kolumbus Amerika?", 1492, "Jahr"),
 ("In welchem Jahr begann die Französische Revolution?", 1789, "Jahr"),
 ("In welchem Jahr wurde die Bundesrepublik Deutschland gegründet?", 1949, "Jahr"),
 ("In welchem Jahr kam das erste iPhone heraus?", 2007, "Jahr"),
 ("In welchem Jahr fiel die Berliner Mauer?", 1989, "Jahr"),
 ("In welchem Jahr landeten Menschen erstmals auf dem Mond?", 1969, "Jahr"),
 ("In welchem Jahr wurde das Euro-Bargeld eingeführt?", 2002, "Jahr"),
 ("In welchem Jahr meldete Carl Benz sein Automobil zum Patent an?", 1886, "Jahr"),
 ("Um welches Jahr druckte Gutenberg mit beweglichen Lettern?", 1450, "Jahr"),
],
"est_koerper": [
 ("Wie viele Knochen hat ein erwachsener Mensch?", 206, "Knochen"),
 ("Wie oft schlägt ein Herz in Ruhe pro Minute (Erwachsene, Durchschnitt)?", 70, "Schläge"),
 ("Wie viele Liter Blut hat ein erwachsener Mensch ungefähr?", 5, "Liter"),
 ("Wie viele Zähne hat ein vollständiges Milchgebiss?", 20, "Zähne"),
 ("Wie lang ist der Dünndarm eines Erwachsenen ungefähr?", 6, "m"),
 ("Wie viele Muskeln hat der Mensch ungefähr?", 650, "Muskeln"),
 ("Wie viel Prozent des Körpers eines Erwachsenen sind Wasser?", 60, "%"),
 ("Wie viele Haare hat ein Mensch ungefähr auf dem Kopf?", 100000, "Haare"),
 ("Wie viele Atemzüge macht ein Erwachsener in Ruhe pro Minute?", 15, "Atemzüge"),
],
"est_tiere": [
 ("Wie schwer kann ein Afrikanischer Elefantenbulle werden?", 6, "t"),
 ("Wie lang kann ein Blauwal werden?", 30, "m"),
 ("Wie schnell kann ein Gepard im Sprint laufen?", 110, "km/h"),
 ("Wie viele Monate ist eine Elefantenkuh trächtig?", 22, "Monate"),
 ("Wie groß kann eine Giraffe werden?", 5.5, "m"),
 ("Wie viele Zähne hat ein erwachsener Hund?", 42, "Zähne"),
 ("Wie viele Stunden schläft eine Katze ungefähr pro Tag?", 15, "Stunden"),
 ("Wie hoch kann ein Riesenkänguru springen?", 3, "m"),
 ("Wie viele Eier legt ein Legehuhn ungefähr pro Jahr?", 300, "Eier"),
],
"est_alltag": [
 ("Wie viele Sekunden hat eine Stunde?", 3600, "Sekunden"),
 ("Wie viele Kilokalorien hat ein Liter Vollmilch ungefähr?", 640, "kcal"),
 ("Wie viele Felder hat ein Schachbrett?", 64, "Felder"),
 ("Wie viele Augen hat ein Spielwürfel insgesamt?", 21, "Augen"),
 ("Wie viel wiegt eine 1-Euro-Münze?", 7.5, "g"),
 ("Wie viele Stichwörter hat der Rechtschreib-Duden (Auflage 2020) ungefähr?", 148000, "Wörter"),
 ("Wie lang ist das deutsche Autobahnnetz ungefähr?", 13200, "km"),
 ("Wie viele Stunden hat eine Woche?", 168, "Stunden"),
 ("Wie viele Minuten dauert ein Handballspiel (reguläre Spielzeit)?", 60, "Minuten"),
],
}

# Emoji-Rätsel: (Emoji-Folge, richtige Antwort, 3 falsche)
EMOJI_CATEGORIES = [
 ("emo_film","🎬","Filme"),("emo_spruch","💬","Sprichwörter"),("emo_ort","🗺️","Länder & Städte"),
 ("emo_beruf","🧑‍🔧","Berufe"),("emo_maerchen","🏰","Märchen"),
]
EMOJI = {
"emo_film": [
 ("🧊🚢💔", "Titanic","Life of Pi","Poseidon","Der Sturm"),
 ("🦁👑", "Der König der Löwen","Madagascar","Das Dschungelbuch","Narnia"),
 ("🦖🏝️🔬", "Jurassic Park","King Kong","Godzilla","Avatar"),
 ("👽📞🏠", "E.T. – Der Außerirdische","Men in Black","Alien","Independence Day"),
 ("🧙‍♂️💍🌋", "Der Herr der Ringe","Harry Potter","Merlin","Narnia"),
 ("🐠🔍", "Findet Nemo","Arielle, die Meerjungfrau","Der weiße Hai","Vaiana"),
 ("❄️👸⛄", "Die Eiskönigin","Cinderella","Schneewittchen","Rapunzel"),
 ("🦈🏖️😱", "Der weiße Hai","Findet Nemo","Baywatch","Titanic"),
 ("🚗⏰⚡", "Zurück in die Zukunft","Cars","Fast & Furious","Speed"),
],
"emo_spruch": [
 ("🍎🌳⬇️", "Der Apfel fällt nicht weit vom Stamm","Ohne Fleiß kein Preis","Morgenstund hat Gold im Mund","Viele Köche verderben den Brei"),
 ("🌅🥇👄", "Morgenstund hat Gold im Mund","Reden ist Silber, Schweigen ist Gold","Der frühe Vogel fängt den Wurm","Ende gut, alles gut"),
 ("🌙🐈🩶", "Nachts sind alle Katzen grau","Wenn die Katze aus dem Haus ist, tanzen die Mäuse","Der Apfel fällt nicht weit vom Stamm","Lügen haben kurze Beine"),
 ("🗣️🥈🤐🥇", "Reden ist Silber, Schweigen ist Gold","Morgenstund hat Gold im Mund","Wer zuletzt lacht, lacht am besten","Übung macht den Meister"),
 ("👨‍🍳👨‍🍳👨‍🍳🍲🤢", "Viele Köche verderben den Brei","Hunger ist der beste Koch","Liebe geht durch den Magen","Was der Bauer nicht kennt, isst er nicht"),
 ("🤥🦵", "Lügen haben kurze Beine","Wer A sagt, muss auch B sagen","Ehrlich währt am längsten","Der Klügere gibt nach"),
 ("🔁🏆", "Übung macht den Meister","Ohne Fleiß kein Preis","Aller Anfang ist schwer","Rom wurde nicht an einem Tag erbaut"),
 ("🐦✋🆚🕊️🏠", "Lieber den Spatz in der Hand als die Taube auf dem Dach","Der frühe Vogel fängt den Wurm","Ein Vogel, der singt, braucht keinen Käfig","Hochmut kommt vor dem Fall"),
 ("🆕🧹✨", "Neue Besen kehren gut","Ordnung ist das halbe Leben","Aller Anfang ist schwer","Wer rastet, der rostet"),
],
"emo_ort": [
 ("🗼🥐🎨", "Paris","Rom","London","Madrid"),
 ("🍕🏛️🛵", "Rom","Athen","Paris","Barcelona"),
 ("🍺🥨🎡", "München","Wien","Köln","Prag"),
 ("🦘🏄☀️", "Australien","Neuseeland","Südafrika","Kanada"),
 ("🗽🍎🚕", "New York","Los Angeles","Chicago","Washington"),
 ("🌷🚲🧀", "Niederlande","Belgien","Dänemark","Schweiz"),
 ("🍁🏒🐻", "Kanada","Russland","Finnland","Norwegen"),
 ("🎭🛶🏛️", "Venedig","Florenz","Neapel","Mailand"),
 ("🍣🗻🌸", "Japan","China","Korea","Thailand"),
],
"emo_beruf": [
 ("🦷🪥", "Zahnarzt/Zahnärztin","Friseur/Friseurin","Optiker/Optikerin","Bäcker/Bäckerin"),
 ("🔥🚒", "Feuerwehrmann/-frau","Polizist/Polizistin","Schornsteinfeger/-in","Rettungssanitäter/-in"),
 ("🍞🥐⏰", "Bäcker/Bäckerin","Metzger/Metzgerin","Gärtner/Gärtnerin","Kellner/Kellnerin"),
 ("✂️💇", "Friseur/Friseurin","Schneider/Schneiderin","Gärtner/Gärtnerin","Kosmetiker/-in"),
 ("🛫🧭☁️", "Pilot/Pilotin","Kapitän/Kapitänin","Lokführer/-in","Busfahrer/-in"),
 ("🔧🚗🛢️", "Kfz-Mechatroniker/-in","Elektriker/-in","Klempner/-in","Taxifahrer/-in"),
 ("📚✏️🏫", "Lehrer/Lehrerin","Bäcker/Bäckerin","Gärtner/Gärtnerin","Ärztin/Arzt"),
 ("🐄🚜🌾", "Landwirt/Landwirtin","Tierarzt/Tierärztin","Metzger/Metzgerin","Gärtner/Gärtnerin"),
 ("🎨🖌️🖼️", "Maler/Malerin","Fotograf/Fotografin","Architekt/Architektin","Schreiner/Schreinerin"),
],
"emo_maerchen": [
 ("🍎👸🪞", "Schneewittchen","Dornröschen","Aschenputtel","Rapunzel"),
 ("👠🎃🕛", "Aschenputtel","Rotkäppchen","Dornröschen","Frau Holle"),
 ("🐺👵🧺", "Rotkäppchen","Hänsel und Gretel","Der Froschkönig","Rumpelstilzchen"),
 ("🍬🏠🧙‍♀️", "Hänsel und Gretel","Frau Holle","Rapunzel","Schneewittchen"),
 ("👸🐸👑", "Der Froschkönig","Dornröschen","Rapunzel","Das tapfere Schneiderlein"),
 ("💯😴🌹🏰", "Dornröschen","Schneewittchen","Frau Holle","Der Froschkönig"),
 ("🌾➡️🥇🤫", "Rumpelstilzchen","Frau Holle","Die Bremer Stadtmusikanten","Hans im Glück"),
 ("🐴🐶🐱🐓🎶", "Die Bremer Stadtmusikanten","Der Wolf und die sieben Geißlein","Hans im Glück","Der gestiefelte Kater"),
 ("🪡🪰7️⃣", "Das tapfere Schneiderlein","Rumpelstilzchen","Hans im Glück","Der gestiefelte Kater"),
],
}

# Seelenverwandt: (Frage, 2–4 Möglichkeiten). Eine Person antwortet ehrlich,
# die andere rät. Keine Antwort ist richtig oder falsch.
SOULMATE_CATEGORIES = [
 ("sm_alltag","☕","Alltag"),("sm_essen","🍕","Essen"),("sm_freizeit","✈️","Reisen & Freizeit"),
 ("sm_liebe","💘","Liebe & Beziehung"),("sm_wenn","🤔","Was wäre wenn"),("sm_typ","🎉","Persönlichkeit"),
]
SOULMATE = {
"sm_alltag": [
 ("Was brauchst du morgens zuerst?", "Kaffee","Tee","Saft oder Wasser","Gar nichts"),
 ("Früh aufstehen oder ausschlafen?", "Früh aufstehen","Ausschlafen"),
 ("Wie hältst du es mit dem Aufräumen?", "Sofort","Wenn es sein muss","Einmal die Woche","Chaos ist Ordnung"),
 ("Wann duschst du lieber?", "Morgens","Abends"),
 ("Wie pünktlich bist du?", "Immer zu früh","Auf die Minute","Leicht zu spät","Chronisch zu spät"),
 ("Welche Tageszeit magst du am liebsten?", "Morgen","Mittag","Abend","Nacht"),
 ("Wie oft ist das Handy beim Essen dabei?", "Nie","Manchmal","Oft"),
 ("Socken im Bett?", "Ja, immer","Nein, niemals"),
 ("Was machst du, wenn der Wecker klingelt?", "Sofort aufstehen","Ein-, zweimal Schlummern","Wecker? Welcher Wecker?"),
],
"sm_essen": [
 ("Pizza oder Pasta?", "Pizza","Pasta"),
 ("Eher süß oder salzig?", "Süß","Salzig"),
 ("Welche Küche ist deine liebste?", "Italienisch","Asiatisch","Deutsch","Mexikanisch"),
 ("Ananas auf Pizza?", "Ja, gerne","Auf keinen Fall"),
 ("Wie stehst du zum Kochen?", "Ich liebe es","Geht so","Lieferdienst ist mein Koch"),
 ("Wie sieht dein ideales Frühstück aus?", "Süß","Herzhaft","Ich frühstücke nicht"),
 ("Wie scharf darf es sein?", "Mild","Mittel","Scharf","Je schärfer, desto besser"),
 ("Popcorn im Kino?", "Süß","Salzig","Gemischt","Kein Popcorn"),
 ("Dein Dessert teilen?", "Gerne","Niemals"),
],
"sm_freizeit": [
 ("Berge oder Meer?", "Berge","Meer"),
 ("Städtetrip oder Natur?", "Städtetrip","Natur"),
 ("Camping oder Hotel?", "Camping","Hotel"),
 ("Wann packst du für eine Reise?", "Last minute","Tage vorher mit Liste"),
 ("Was muss im Urlaub sein?", "Action","Entspannung","Kultur","Party"),
 ("Wie sieht dein perfektes Wochenende aus?", "Unterwegs sein","Couch und Serien","Zeit mit Freunden","Ein kleines Abenteuer"),
 ("Welche Jahreszeit magst du am liebsten?", "Frühling","Sommer","Herbst","Winter"),
 ("Konzert oder Kino?", "Konzert","Kino"),
 ("Im Flugzeug lieber …", "am Fenster","am Gang"),
],
"sm_liebe": [
 ("Wie sieht dein ideales erstes Date aus?", "Kaffee trinken","Abendessen","Etwas unternehmen","Spazieren gehen"),
 ("Woran merkst du am meisten, dass dich jemand mag?", "Liebe Worte","Gemeinsame Zeit","Kleine Geschenke","Nähe und Berührung"),
 ("Nach einem Streit …", "sofort klären","erst mal abkühlen"),
 ("Valentinstag ist …", "ein großes Ding","ganz nett","reiner Kommerz"),
 ("Wer schreibt nach einem Date zuerst?", "Ich","Die andere Person","Egal, wer zuerst Lust hat"),
 ("Kuscheln beim Einschlafen?", "Ja, die ganze Nacht","Kurz, dann jeder für sich","Lieber nicht"),
 ("Überraschungen …", "liebe ich","plane ich lieber gemeinsam"),
 ("Was ist für dich am romantischsten?", "Candle-Light-Dinner","Picknick","Roadtrip","Zusammen kochen"),
 ("Wie eifersüchtig bist du?", "Gar nicht","Ein bisschen","Ziemlich"),
],
"sm_wenn": [
 ("Welche Superkraft hättest du gern?", "Fliegen","Unsichtbar sein","Gedanken lesen","Teleportieren"),
 ("Zeitreise: wohin?", "Vergangenheit","Zukunft"),
 ("Was nimmst du mit auf eine einsame Insel?", "Ein Buch","Musik","Ein Messer","Einen Lieblingsmenschen"),
 ("Was machst du zuerst mit einem Lottogewinn?", "Reisen","Ein Haus kaufen","Spenden","Sparen"),
 ("Worauf könntest du am ehesten für immer verzichten?", "Musik","Filme und Serien","Schokolade","Social Media"),
 ("Welches Tier wärst du gern für einen Tag?", "Vogel","Delfin","Katze","Hund"),
 ("Wo würdest du am liebsten leben?", "Großstadt","Kleinstadt","Auf dem Land","Im Ausland"),
 ("Wofür hättest du gern unendlich Zeit?", "Schlafen","Reisen","Lernen","Freunde"),
 ("Mit wem würdest du am liebsten mal essen gehen?", "Einer Musikerin","Einem Sportler","Einer Schauspielerin","Einem Wissenschaftler"),
],
"sm_typ": [
 ("Wie bist du auf Partys?", "Mittelpunkt","Mit Freunden in der Ecke","Taue erst spät auf","Lieber zu Hause"),
 ("Planst du gern oder bist du spontan?", "Planer:in","Spontan"),
 ("Wie würdest du dich beschreiben?", "Eher introvertiert","Eher extrovertiert","Irgendwo dazwischen"),
 ("Weinst du bei Filmen?", "Oft","Selten","Nie"),
 ("Musik im Auto …", "laut und mitsingen","im Hintergrund","lieber Stille"),
 ("Sprachnachrichten?", "Liebe ich","Nur kurze","Bitte nicht"),
 ("Welches Gefühl suchst du am meisten?", "Abenteuer","Geborgenheit","Freiheit","Erfolg"),
 ("Bist du ein Morgenmuffel?", "Ja, sehr","Ein bisschen","Gar nicht"),
 ("Wie spielst du Gesellschaftsspiele?", "Ehrgeizig","Spaß zählt","Lieber gar nicht"),
],
}

# Art jedes Spiels: (Schlüssel, Kategorien, Fragen)
KINDS = [
 ("quiz", CATEGORIES, Q),
 ("estimate", ESTIMATE_CATEGORIES, ESTIMATE),
 ("emoji", EMOJI_CATEGORIES, EMOJI),
 ("soulmate", SOULMATE_CATEGORIES, SOULMATE),
]


def build():
    categories, questions = [], []
    next_id = 1
    for kind, cats, qs in KINDS:
        for key, emoji, label in cats:
            categories.append({"key": key, "emoji": emoji, "label": label, "kind": kind})
        for key, _, _ in cats:
            for item in qs[key]:
                q = {"id": next_id, "category": key, "question": item[0]}
                if kind == "estimate":
                    q["answers"] = []
                    q["number"] = item[1]
                    q["unit"] = item[2]
                else:
                    q["answers"] = list(item[1:])
                    assert 2 <= len(q["answers"]) <= 4, item
                    assert len(set(q["answers"])) == len(q["answers"]), item
                questions.append(q)
                next_id += 1
    return {"categories": categories, "questions": questions}


def sql_for(data, since_id):
    def lit(t): return "'" + str(t).replace("'", "''") + "'"
    qs = [q for q in data["questions"] if q["id"] > since_id]
    new_cats = {q["category"] for q in qs}
    old_cats = {q["category"] for q in data["questions"] if q["id"] <= since_id}
    assert not (new_cats & old_cats), "Neue Fragen in alter Kategorie: eigene Migration schreiben"
    cats = [c for c in data["categories"] if c["key"] in new_cats]
    cat_rows = ",\n".join(
        f"  ({lit(c['key'])}, {lit(c['emoji'])}, {lit(c['label'])}, {lit(c['kind'])})"
        for c in cats)
    def row(q):
        answers = "array[" + ", ".join(lit(a) for a in q["answers"]) + "]" if q["answers"] else "'{}'::text[]"
        num = str(q["number"]) if "number" in q else "null"
        unit = lit(q["unit"]) if "unit" in q else "null"
        return f"  ({q['id']}, {lit(q['category'])}, {lit(q['question'])}, {answers}, {num}, {unit})"
    return ("-- GENERIERT von tool/quiz_questions.py – nicht von Hand ändern.\n"
            f"-- Fragen ab ID {since_id + 1}. Bei Auswahlfragen ist die erste Antwort die richtige\n"
            "-- (außer Seelenverwandt: dort gibt es keine richtige Antwort).\n\n"
            "insert into public.quiz_categories (key, emoji, label, kind) values\n" + cat_rows + ";\n\n"
            "insert into public.quiz_questions (id, category, question, answers, number_answer, unit) values\n"
            + ",\n".join(row(q) for q in qs) + ";\n\n"
            "select setval(pg_get_serial_sequence('public.quiz_questions', 'id'),"
            " (select max(id) from public.quiz_questions));\n")


if __name__ == "__main__":
    import json, pathlib, sys
    root = pathlib.Path(__file__).resolve().parent.parent
    data = build()
    (root / "assets/quiz/questions.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    args = sys.argv[1:]
    if args:
        since = int(args[args.index("--since-id") + 1]) if "--since-id" in args else 0
        (root / args[0]).write_text(sql_for(data, since))
    print(len(data["questions"]), "Fragen")
