#!/usr/bin/env python3
"""Build the recipe seed catalogue.

The design ships 12 dishes with names, subtitles, times, XP and gradients, plus
a full ingredient and step list for Doro Wat. That is the starting point, not
the whole catalogue: the brief asks for 25-30 recipes, so the rest are written
here with the same shape.

Cultural notes are written as tradition rather than asserted history. "In much
of Ethiopia this is the dish that ends a fast" is a description of practice;
"invented in the 13th century" would be a claim this project has no business
making. Nothing here dates a dish or names an inventor.

Output: assets/seed/recipes.json, bundled with the app so a first run has a
catalogue with no network, and used by tool/seed_firestore.dart to populate the
backend.

Usage:  python3 tool/build_seed.py
"""

import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESIGN = os.path.join(ROOT, 'design', 'extracted', 'seed.json')
OUT = os.path.join(ROOT, 'assets', 'seed', 'recipes.json')

SPICE, FRESH, MEAT, PANTRY = 'spice', 'fresh', 'meatDairy', 'pantry'


def ing(name, name_am, qty, unit, unit_am, aisle=PANTRY, optional=False):
    return {
        'name': name, 'nameAm': name_am, 'quantity': qty,
        'unit': unit, 'unitAm': unit_am, 'aisle': aisle, 'optional': optional,
    }


def step(i, text, text_am, seconds=None, tip=None, tip_am=None):
    out = {'index': i, 'text': text, 'textAm': text_am, 'optional': False}
    if seconds:
        out['durationSeconds'] = seconds
    if tip:
        out['tip'] = tip
        out['tipAm'] = tip_am
    return out


# Recipes beyond the design's 12. Same shape, written for this catalogue.
EXTRA = {
    'chechebsa': {
        'en': 'Chechebsa', 'am': 'ጨጨብሳ',
        'se': 'Torn flatbread · niter kibbeh · berbere',
        'sa': 'የተቀደደ ቂጣ · ንጥር ቅቤ · በርበሬ',
        'min': 25, 'xp': 70, 'lv': 0, 'a': '#8A4A16', 'b': '#D98F3C',
        'region': 'oromia', 'category': 'breakfast', 'heat': 2,
        'fasting': False, 'vegan': False, 'gf': False, 'df': False,
        'story': ('A breakfast of torn flatbread tossed in spiced butter, eaten '
                  'in many Oromo homes with yoghurt or honey alongside. It is '
                  'quick by design -- the bread is made, torn and dressed in the '
                  'same morning.'),
        'storyAm': ('የተቀደደ ቂጣ በቅመም ቅቤ ተለውሶ የሚበላ ቁርስ ሲሆን በብዙ የኦሮሞ ቤቶች ከእርጎ ወይም '
                    'ከማር ጋር ይቀርባል። በአንድ ጠዋት ተሠርቶ ተቀዶ ይዘጋጃል።'),
        'ingredients': [
            ing('Kita flatbread', 'ቂጣ', 1, 'large', 'ትልቅ', PANTRY),
            ing('Niter kibbeh', 'ንጥር ቅቤ', 0.33, 'cup', 'ኩባያ', MEAT),
            ing('Berbere', 'በርበሬ', 2, 'tbsp', 'የሾርባ ማንኪያ', SPICE),
            ing('Honey', 'ማር', 2, 'tbsp', 'የሾርባ ማንኪያ', PANTRY, True),
            ing('Yoghurt', 'እርጎ', 0.5, 'cup', 'ኩባያ', MEAT, True),
        ],
        'steps': [
            ('Make a plain kita and let it cool enough to handle.',
             'ተራ ቂጣ ሠርተው እስኪበርድ ያቆዩት።', None),
            ('Tear it into rough pieces the size of a thumbnail.',
             'የጥፍር ያህል በሆነ መጠን ይቀዱት።', None),
            ('Melt the niter kibbeh in a wide pan over low heat.',
             'ንጥር ቅቤውን በሰፊ ድስት በዝቅተኛ እሳት ያቅልጡት።', 120),
            ('Stir in the berbere and let it bloom without burning.',
             'በርበሬውን ጨምረው ሳይቃጠል እንዲፈታ ያድርጉ።', 90),
            ('Toss the torn bread through until every piece is coated.',
             'የተቀደደውን ቂጣ እያንዳንዱ ቁራጭ እስኪለበስ ይቀላቅሉ።', 180),
            ('Serve hot, with honey or yoghurt if you like.',
             'ሙቅ ሆኖ ከማር ወይም ከእርጎ ጋር ያቅርቡ።', None),
        ],
    },
    'genfo': {
        'en': 'Genfo', 'am': 'ገንፎ',
        'se': 'Barley porridge · kibbeh well · berbere',
        'sa': 'የገብስ ገንፎ · የቅቤ ጉድጓድ · በርበሬ',
        'min': 30, 'xp': 65, 'lv': 0, 'a': '#7A6A2A', 'b': '#C9B45C',
        'region': 'amhara', 'category': 'breakfast', 'heat': 1,
        'fasting': False, 'vegan': False, 'gf': False, 'df': False,
        'story': ('A stiff barley porridge shaped into a mound with a well of '
                  'spiced butter in the middle. Often served to new mothers and '
                  'on cold mornings, it is eaten from the outside in.'),
        'storyAm': ('የገብስ ገንፎ ተከምሮ መሃሉ ላይ የቅመም ቅቤ ጉድጓድ ይሠራለታል። ብዙ ጊዜ ለወላድ '
                    'እናቶችና በቀዝቃዛ ጠዋቶች የሚቀርብ ሲሆን ከዳር ወደ መሃል ይበላል።'),
        'ingredients': [
            ing('Barley flour', 'የገብስ ዱቄት', 2, 'cups', 'ኩባያ', PANTRY),
            ing('Water', 'ውሃ', 3, 'cups', 'ኩባያ', PANTRY),
            ing('Niter kibbeh', 'ንጥር ቅቤ', 0.25, 'cup', 'ኩባያ', MEAT),
            ing('Berbere', 'በርበሬ', 2, 'tbsp', 'የሾርባ ማንኪያ', SPICE),
            ing('Salt', 'ጨው', 0, 'to taste', 'እንደ አስፈላጊነቱ', SPICE),
        ],
        'steps': [
            ('Bring the salted water to a rolling boil.',
             'የጨው ውሃውን አፍልተው ያፍሉት።', 300),
            ('Add the barley flour all at once and stop stirring.',
             'የገብስ ዱቄቱን በአንድ ጊዜ ጨምረው ማማሰሉን ያቁሙ።', 60),
            ('Cover and let it steam through.',
             'ሸፍነው በእንፋሎት እንዲበስል ያድርጉ።', 300),
            ('Beat it hard with a wooden spoon until smooth and stiff.',
             'በእንጨት ማንኪያ ለስላሳና ጠጣር እስኪሆን ድረስ ይምቱት።', 240),
            ('Shape into a mound and press a well into the centre.',
             'ክምር አድርገው መሃሉ ላይ ጉድጓድ ይሥሩ።', None),
            ('Melt the kibbeh with berbere and pour it into the well.',
             'ቅቤውን ከበርበሬ ጋር አቅልጠው ጉድጓዱ ውስጥ ያፍሱ።', 120),
        ],
    },
    'atakilt': {
        'en': 'Atakilt Wat', 'am': 'አትክልት ወጥ',
        'se': 'Cabbage · carrot · potato · turmeric',
        'sa': 'ጥቅል ጎመን · ካሮት · ድንች · እርድ',
        'min': 40, 'xp': 75, 'lv': 0, 'a': '#6E7A18', 'b': '#B9C64A',
        'region': 'amhara', 'category': 'fasting', 'heat': 0,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('A gentle turmeric-yellow vegetable stew with no berbere at '
                  'all, which is what makes it a fasting-table staple and a '
                  'good first dish for anyone wary of heat.'),
        'storyAm': ('በእርድ የሚቀላ ለስላሳ የአትክልት ወጥ ሲሆን በርበሬ አልያዘም። ለጾም ማዕድ ዋነኛ ሲሆን '
                    'ቅመም ለሚፈሩ ሰዎችም ጥሩ መጀመሪያ ነው።'),
        'ingredients': [
            ing('Cabbage', 'ጥቅል ጎመን', 0.5, 'head', 'ራስ', FRESH),
            ing('Carrots', 'ካሮት', 3, '', '', FRESH),
            ing('Potatoes', 'ድንች', 3, '', '', FRESH),
            ing('Onion', 'ሽንኩርት', 1, 'large', 'ትልቅ', FRESH),
            ing('Turmeric', 'እርድ', 1, 'tsp', 'የሻይ ማንኪያ', SPICE),
            ing('Garlic', 'ነጭ ሽንኩርት', 4, 'cloves', 'ቅንጣት', FRESH),
            ing('Oil', 'ዘይት', 0.25, 'cup', 'ኩባያ', PANTRY),
        ],
        'steps': [
            ('Slice the onion and soften it in oil.',
             'ሽንኩርቱን ከትፈው በዘይት ያለሰልሱት።', 420),
            ('Add garlic and turmeric and stir for a minute.',
             'ነጭ ሽንኩርትና እርድ ጨምረው ለአንድ ደቂቃ ያማስሉ።', 60),
            ('Add carrots and potatoes cut into thick batons.',
             'ካሮትና ድንቹን ወፍራም አድርገው ቆርጠው ይጨምሩ።', 60),
            ('Add the shredded cabbage and a splash of water.',
             'የተከተፈውን ጎመንና ትንሽ ውሃ ይጨምሩ።', 60),
            ('Cover and cook low until everything is tender.',
             'ሸፍነው ሁሉም እስኪለሰልስ በዝቅተኛ እሳት ያብስሉ።', 1200),
        ],
    },
    'bozena': {
        'en': 'Bozena Shiro', 'am': 'ቦዘና ሽሮ',
        'se': 'Shiro · shredded beef · berbere',
        'sa': 'ሽሮ · የተከተፈ ሥጋ · በርበሬ',
        'min': 50, 'xp': 130, 'lv': 1, 'a': '#7A3A12', 'b': '#C97A32',
        'region': 'amhara', 'category': 'wat', 'heat': 3,
        'fasting': False, 'vegan': False, 'gf': True, 'df': False,
        'story': ('Shiro with meat stirred through it -- the version cooked when '
                  'a fast has ended and there is dried beef in the house.'),
        'storyAm': ('ሥጋ የተጨመረበት ሽሮ ሲሆን ጾም ሲፈታና በቤት ውስጥ ቋንጣ ሲኖር የሚሠራው ዓይነት ነው።'),
        'ingredients': [
            ing('Shiro powder', 'የሽሮ ዱቄት', 1, 'cup', 'ኩባያ', PANTRY),
            ing('Dried beef (quanta)', 'ቋንጣ', 200, 'g', 'ግራም', MEAT),
            ing('Niter kibbeh', 'ንጥር ቅቤ', 0.25, 'cup', 'ኩባያ', MEAT),
            ing('Onion', 'ሽንኩርት', 1, '', '', FRESH),
            ing('Berbere', 'በርበሬ', 2, 'tbsp', 'የሾርባ ማንኪያ', SPICE),
            ing('Garlic', 'ነጭ ሽንኩርት', 4, 'cloves', 'ቅንጣት', FRESH),
        ],
        'steps': [
            ('Dry-cook the diced onion until it collapses.',
             'የተከተፈውን ሽንኩርት እስኪለሰልስ በደረቁ ያብስሉ።', 600),
            ('Add kibbeh and berbere and cook the spice out.',
             'ቅቤና በርበሬ ጨምረው ቅመሙን ያብስሉት።', 480),
            ('Add the shredded dried beef and turn it through.',
             'የተከተፈውን ቋንጣ ጨምረው ይገልብጡት።', 300),
            ('Whisk the shiro powder into water, then pour it in slowly.',
             'የሽሮ ዱቄቱን በውሃ አማስለው ቀስ ብለው ያፍሱት።', 120),
            ('Simmer, stirring, until it thickens and stops tasting raw.',
             'እያማሰሉ እስኪወፍርና ጥሬነቱ እስኪለቅ ያንተከትኩ።', 900),
        ],
    },
    'fosolia': {
        'en': 'Fosolia', 'am': 'ፎሶሊያ',
        'se': 'Green beans · carrot · garlic',
        'sa': 'ፎሶሊያ · ካሮት · ነጭ ሽንኩርት',
        'min': 25, 'xp': 60, 'lv': 0, 'a': '#2A6A2A', 'b': '#6FBF5F',
        'region': 'amhara', 'category': 'fasting', 'heat': 0,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('Green beans and carrots cooked down with onion and garlic. A '
                  'quiet dish that shares the fasting plate with louder ones.'),
        'storyAm': ('ፎሶሊያና ካሮት ከሽንኩርትና ነጭ ሽንኩርት ጋር የሚበስል ነው። ጸጥ ያለ ምግብ ሲሆን '
                    'በጾም ማዕድ ላይ ከሌሎች ጋር ይቀርባል።'),
        'ingredients': [
            ing('Green beans', 'ፎሶሊያ', 500, 'g', 'ግራም', FRESH),
            ing('Carrots', 'ካሮት', 2, '', '', FRESH),
            ing('Onion', 'ሽንኩርት', 1, '', '', FRESH),
            ing('Garlic', 'ነጭ ሽንኩርት', 3, 'cloves', 'ቅንጣት', FRESH),
            ing('Oil', 'ዘይት', 3, 'tbsp', 'የሾርባ ማንኪያ', PANTRY),
        ],
        'steps': [
            ('Top and tail the beans; cut the carrots to match.',
             'የፎሶሊያውን ጫፍ ቆርጠው ካሮቱን በተመሳሳይ ይቁረጡ።', None),
            ('Soften the sliced onion in oil.',
             'የተከተፈውን ሽንኩርት በዘይት ያለሰልሱት።', 360),
            ('Add garlic, then the vegetables.',
             'ነጭ ሽንኩርት ከዚያም አትክልቶቹን ይጨምሩ።', 60),
            ('Cover and cook until tender but still green.',
             'ሸፍነው እስኪለሰልሱ ግን አረንጓዴነታቸውን ሳይለቁ ያብስሉ።', 900),
        ],
    },
    'alicha': {
        'en': 'Alicha Wat', 'am': 'አልጫ ወጥ',
        'se': 'Beef · turmeric · no berbere',
        'sa': 'የበሬ ሥጋ · እርድ · በርበሬ የለም',
        'min': 70, 'xp': 120, 'lv': 1, 'a': '#8A7A18', 'b': '#DCC845',
        'region': 'amhara', 'category': 'wat', 'heat': 0,
        'fasting': False, 'vegan': False, 'gf': True, 'df': False,
        'story': ('The mild counterpart to a berbere wat: turmeric instead of '
                  'chilli, cooked long and gently. Often the dish put in front '
                  'of children and elders at the same table.'),
        'storyAm': ('የበርበሬ ወጥ ለስላሳ አቻ ሲሆን በርበሬ ሳይሆን እርድ ይጠቀማል፤ ረጅም ጊዜ በእርጋታ '
                    'ይበስላል። ብዙ ጊዜ በአንድ ማዕድ ላይ ለልጆችና ለአዛውንቶች የሚቀርበው ነው።'),
        'ingredients': [
            ing('Beef, cubed', 'የተከተፈ የበሬ ሥጋ', 800, 'g', 'ግራም', MEAT),
            ing('Onion', 'ሽንኩርት', 2, 'large', 'ትልቅ', FRESH),
            ing('Turmeric', 'እርድ', 2, 'tsp', 'የሻይ ማንኪያ', SPICE),
            ing('Ginger', 'ዝንጅብል', 1, 'in', 'ኢንች', FRESH),
            ing('Garlic', 'ነጭ ሽንኩርት', 5, 'cloves', 'ቅንጣት', FRESH),
            ing('Niter kibbeh', 'ንጥር ቅቤ', 0.33, 'cup', 'ኩባያ', MEAT),
        ],
        'steps': [
            ('Dry-cook the onions until soft and pale.',
             'ሽንኩርቱን እስኪለሰልስና እስኪገረጣ በደረቁ ያብስሉ።', 720),
            ('Add kibbeh, turmeric, garlic and ginger.',
             'ቅቤ፣ እርድ፣ ነጭ ሽንኩርትና ዝንጅብል ይጨምሩ።', 180),
            ('Add the beef and turn until sealed.',
             'ሥጋውን ጨምረው እስኪለበስ ይገልብጡ።', 300),
            ('Add water to barely cover and simmer low.',
             'ውሃ ሸፍኖት እስኪያልፍ ጨምረው በዝቅተኛ እሳት ያንተከትኩ።', 2700),
        ],
    },
    'ayib': {
        'en': 'Ayib', 'am': 'አይብ',
        'se': 'Fresh cheese · pressed curd',
        'sa': 'ትኩስ አይብ · የተጨመቀ',
        'min': 45, 'xp': 55, 'lv': 0, 'a': '#8A8A7A', 'b': '#E4E0D2',
        'region': 'amhara', 'category': 'side', 'heat': 0,
        'fasting': False, 'vegan': False, 'gf': True, 'df': False,
        'story': ('A mild fresh cheese, crumbly and barely salted. Its job is '
                  'to sit next to something fierce -- kitfo, or a hot wat -- and '
                  'cool it down.'),
        'storyAm': ('ለስላሳና ትንሽ ጨው ያለው ትኩስ አይብ ነው። ሥራው ከሚያቃጥል ምግብ -- ከክትፎ ወይም '
                    'ከሚያቃጥል ወጥ -- አጠገብ ሆኖ ማብረድ ነው።'),
        'ingredients': [
            ing('Buttermilk', 'አረራ', 2, 'l', 'ሊትር', MEAT),
            ing('Salt', 'ጨው', 0, 'to taste', 'እንደ አስፈላጊነቱ', SPICE),
        ],
        'steps': [
            ('Warm the buttermilk gently. Do not let it boil.',
             'አረራውን በእርጋታ ያሙቁት። እንዲፈላ አይፍቀዱ።', 900),
            ('Let the curds separate and rise.',
             'እርጎው ተለይቶ እንዲወጣ ያድርጉ።', 600),
            ('Strain through cloth and press out the whey.',
             'በጨርቅ አጣርተው ውሃውን ይጭመቁት።', 1200),
            ('Salt lightly and serve cool.',
             'ትንሽ ጨው ጨምረው ቀዝቃዛ ሆኖ ያቅርቡ።', None),
        ],
    },
    'awaze': {
        'en': 'Awaze', 'am': 'አዋዜ',
        'se': 'Berbere · wine · garlic paste',
        'sa': 'በርበሬ · ወይን · ነጭ ሽንኩርት',
        'min': 15, 'xp': 45, 'lv': 0, 'a': '#7A1010', 'b': '#C43A2A',
        'region': 'amhara', 'category': 'condiment', 'heat': 4,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('A berbere paste loosened with wine or tej, served beside '
                  'tibs and kitfo for anyone who wants more heat than the dish '
                  'already carries.'),
        'storyAm': ('በወይን ወይም በጠጅ የተለወሰ የበርበሬ ለጥ ሲሆን ከምግቡ በላይ ቅመም ለሚፈልጉ '
                    'ከጥብስና ከክትፎ ጎን ይቀርባል።'),
        'ingredients': [
            ing('Berbere', 'በርበሬ', 0.5, 'cup', 'ኩባያ', SPICE),
            ing('Red wine or tej', 'ወይን ወይም ጠጅ', 3, 'tbsp', 'የሾርባ ማንኪያ', PANTRY),
            ing('Garlic', 'ነጭ ሽንኩርት', 2, 'cloves', 'ቅንጣት', FRESH),
        ],
        'steps': [
            ('Crush the garlic to a paste with a little salt.',
             'ነጭ ሽንኩርቱን ከትንሽ ጨው ጋር ወቅጠው ለጥ ያድርጉት።', None),
            ('Stir the berbere into the wine a spoon at a time.',
             'በርበሬውን በማንኪያ እየጨመሩ ከወይኑ ጋር ያማስሉ።', 180),
            ('Rest it so the spice softens before serving.',
             'ቅመሙ እንዲለሰልስ አሳርፈው ያቅርቡት።', 600),
        ],
    },
    'tihlo': {
        'en': 'Tihlo', 'am': 'ጥሕሎ',
        'se': 'Roasted barley dough · fork-eaten',
        'sa': 'የተጠበሰ የገብስ ሊጥ · በሹካ',
        'min': 60, 'xp': 140, 'lv': 1, 'a': '#5A4A2A', 'b': '#A8905C',
        'region': 'tigray', 'category': 'grain', 'heat': 2,
        'fasting': False, 'vegan': False, 'gf': False, 'df': False,
        'story': ('Balls of roasted barley dough, speared on a small wooden fork '
                  'and dipped in a spiced sauce. Associated with Tigray, and '
                  'eaten communally from one dish.'),
        'storyAm': ('የተጠበሰ የገብስ ሊጥ ኳስ ሲሆን በትንሽ የእንጨት ሹካ ተወግቶ በቅመም መረቅ ይጠቀሳል። '
                    'ከትግራይ ጋር የተያያዘ ሲሆን ከአንድ ሰሃን በጋራ ይበላል።'),
        'ingredients': [
            ing('Roasted barley flour', 'የተጠበሰ የገብስ ዱቄት', 3, 'cups', 'ኩባያ', PANTRY),
            ing('Water', 'ውሃ', 2, 'cups', 'ኩባያ', PANTRY),
            ing('Berbere', 'በርበሬ', 3, 'tbsp', 'የሾርባ ማንኪያ', SPICE),
            ing('Niter kibbeh', 'ንጥር ቅቤ', 0.25, 'cup', 'ኩባያ', MEAT),
            ing('Beef, diced', 'የተከተፈ ሥጋ', 300, 'g', 'ግራም', MEAT, True),
        ],
        'steps': [
            ('Work the flour and warm water into a stiff dough.',
             'ዱቄቱንና ለብ ያለ ውሃ አዋህደው ጠጣር ሊጥ ያድርጉት።', 600),
            ('Roll it into small balls and keep them covered.',
             'ትንንሽ ኳሶች አድርገው ሸፍነው ያስቀምጡ።', 600),
            ('Build a berbere sauce with kibbeh and onion.',
             'በቅቤና በሽንኩርት የበርበሬ መረቅ ይሥሩ።', 900),
            ('Serve the balls around the sauce, with forks.',
             'ኳሶቹን በመረቁ ዙሪያ ከሹካ ጋር ያቅርቡ።', None),
        ],
    },
    'shorba': {
        'en': 'Shorba', 'am': 'ሾርባ',
        'se': 'Lentil broth · cumin · fast-breaking',
        'sa': 'የምስር ሾርባ · ከሙን · ጾም መፍቻ',
        'min': 35, 'xp': 60, 'lv': 0, 'a': '#8A5A20', 'b': '#D9A050',
        'region': 'harar', 'category': 'soup', 'heat': 1,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('A thin lentil broth, often the first thing eaten when a fast '
                  'is broken because it is gentle on an empty stomach.'),
        'storyAm': ('ቀጭን የምስር ሾርባ ሲሆን ባዶ ሆድ ላይ ቀላል ስለሆነ ጾም ሲፈታ መጀመሪያ የሚበላ ነው።'),
        'ingredients': [
            ing('Red lentils', 'ቀይ ምስር', 1, 'cup', 'ኩባያ', PANTRY),
            ing('Onion', 'ሽንኩርት', 1, '', '', FRESH),
            ing('Cumin', 'ከሙን', 1, 'tsp', 'የሻይ ማንኪያ', SPICE),
            ing('Tomato', 'ቲማቲም', 1, '', '', FRESH),
            ing('Oil', 'ዘይት', 2, 'tbsp', 'የሾርባ ማንኪያ', PANTRY),
        ],
        'steps': [
            ('Soften onion in oil with the cumin.',
             'ሽንኩርቱን ከከሙን ጋር በዘይት ያለሰልሱት።', 360),
            ('Add chopped tomato and let it break down.',
             'የተከተፈ ቲማቲም ጨምረው እንዲፈርስ ያድርጉ።', 300),
            ('Add lentils and plenty of water.',
             'ምስርና በቂ ውሃ ይጨምሩ።', 60),
            ('Simmer until the lentils fall apart.',
             'ምስሩ እስኪፈርስ ያንተከትኩ።', 1500),
        ],
    },
    'kinche': {
        'en': 'Kinche', 'am': 'ቅንጬ',
        'se': 'Cracked wheat · kibbeh · plain',
        'sa': 'ስንዴ ፍርፍር · ቅቤ · ተራ',
        'min': 30, 'xp': 55, 'lv': 0, 'a': '#7A7A5A', 'b': '#CFC7A0',
        'region': 'amhara', 'category': 'breakfast', 'heat': 0,
        'fasting': False, 'vegan': False, 'gf': False, 'df': False,
        'story': ('Cracked wheat boiled soft and dressed with spiced butter. '
                  'Plain on purpose -- a breakfast that does not compete with the '
                  'coffee that follows it.'),
        'storyAm': ('የተፈጨ ስንዴ ለስላሳ እስኪሆን ተቀቅሎ በቅመም ቅቤ ይለወሳል። ሆን ተብሎ ተራ ነው -- '
                    'ከሚከተለው ቡና ጋር የማይወዳደር ቁርስ።'),
        'ingredients': [
            ing('Cracked wheat', 'ስንዴ ፍርፍር', 1.5, 'cups', 'ኩባያ', PANTRY),
            ing('Water', 'ውሃ', 3, 'cups', 'ኩባያ', PANTRY),
            ing('Niter kibbeh', 'ንጥር ቅቤ', 3, 'tbsp', 'የሾርባ ማንኪያ', MEAT),
            ing('Salt', 'ጨው', 0, 'to taste', 'እንደ አስፈላጊነቱ', SPICE),
        ],
        'steps': [
            ('Rinse the cracked wheat until the water runs clear.',
             'ስንዴውን ውሃው እስኪጠራ ያጠቡት።', 180),
            ('Boil in salted water until soft.',
             'በጨው ውሃ እስኪለሰልስ ያብስሉት።', 1200),
            ('Drain, then stir the kibbeh through while hot.',
             'አጣርተው ሙቅ ሳለ ቅቤውን ይቀላቅሉ።', 120),
        ],
    },
    'ful': {
        'en': 'Ful', 'am': 'ፉል',
        'se': 'Fava beans · onion · chilli · bread',
        'sa': 'ባቄላ · ሽንኩርት · ቃሪያ · ዳቦ',
        'min': 25, 'xp': 60, 'lv': 0, 'a': '#5A5A2A', 'b': '#A8A050',
        'region': 'harar', 'category': 'breakfast', 'heat': 2,
        'fasting': True, 'vegan': True, 'gf': False, 'df': True,
        'story': ('Stewed fava beans mashed at the table, eaten from a shared '
                  'bowl with bread. Common in Harar and across the east, and a '
                  'fixture of morning eating houses.'),
        'storyAm': ('የበሰለ ባቄላ በማዕድ ላይ ተፈጭቶ ከዳቦ ጋር ከጋራ ሰሃን ይበላል። በሐረርና በምሥራቁ '
                    'አካባቢ የተለመደ ሲሆን የጠዋት ምግብ ቤቶች ዋነኛ ነው።'),
        'ingredients': [
            ing('Fava beans, cooked', 'የበሰለ ባቄላ', 2, 'cups', 'ኩባያ', PANTRY),
            ing('Onion', 'ሽንኩርት', 1, '', '', FRESH),
            ing('Green chilli', 'ቃሪያ', 2, '', '', FRESH),
            ing('Tomato', 'ቲማቲም', 1, '', '', FRESH),
            ing('Oil', 'ዘይት', 2, 'tbsp', 'የሾርባ ማንኪያ', PANTRY),
            ing('Bread', 'ዳቦ', 1, 'loaf', 'ዳቦ', PANTRY),
        ],
        'steps': [
            ('Warm the beans through with a little of their liquid.',
             'ባቄላውን ከትንሽ ውሃው ጋር ያሙቁት።', 300),
            ('Mash roughly -- it should not be smooth.',
             'ሻካራ አድርገው ይፍጩት -- ለስላሳ መሆን የለበትም።', 120),
            ('Top with raw onion, chilli, tomato and oil.',
             'ጥሬ ሽንኩርት፣ ቃሪያ፣ ቲማቲምና ዘይት ይጨምሩበት።', None),
            ('Serve with bread torn to scoop.',
             'ለመጎረስ ከተቀደደ ዳቦ ጋር ያቅርቡ።', None),
        ],
    },
    'dabo': {
        'en': 'Ambasha', 'am': 'አንባሻ',
        'se': 'Celebration bread · scored top',
        'sa': 'የበዓል ዳቦ · የተቀረጸ ላይ',
        'min': 180, 'xp': 150, 'lv': 1, 'a': '#8A6A2A', 'b': '#D9B060',
        'region': 'tigray', 'category': 'bread', 'heat': 0,
        'fasting': True, 'vegan': True, 'gf': False, 'df': True,
        'story': ('A round, slightly sweet bread scored across the top before '
                  'baking. Made for holidays and guests; the pattern is cut so '
                  'it can be torn into even shares.'),
        'storyAm': ('ክብ፣ ትንሽ ጣፋጭ ዳቦ ሲሆን ከመጋገሩ በፊት ላዩ ላይ ይቀረጻል። ለበዓላትና ለእንግዶች '
                    'የሚሠራ ሲሆን እኩል ለመከፋፈል እንዲመች ነው የሚቀረጸው።'),
        'ingredients': [
            ing('Flour', 'ዱቄት', 4, 'cups', 'ኩባያ', PANTRY),
            ing('Yeast', 'እርሾ', 2, 'tsp', 'የሻይ ማንኪያ', PANTRY),
            ing('Sugar', 'ስኳር', 2, 'tbsp', 'የሾርባ ማንኪያ', PANTRY),
            ing('Oil', 'ዘይት', 0.25, 'cup', 'ኩባያ', PANTRY),
            ing('Water', 'ውሃ', 1.5, 'cups', 'ኩባያ', PANTRY),
        ],
        'steps': [
            ('Bloom the yeast in warm water with the sugar.',
             'እርሾውን ከስኳር ጋር በለብ ያለ ውሃ ያንቁት።', 600),
            ('Work everything into a soft dough and knead it well.',
             'ሁሉንም አዋህደው ለስላሳ ሊጥ አድርገው በደንብ ያቡኩት።', 900),
            ('Let it rise until doubled.',
             'እጥፍ እስኪሆን ያቡኩት።', 3600),
            ('Shape into a round and score the pattern across the top.',
             'ክብ አድርገው ላዩ ላይ ንድፍ ይቅረጹ።', 300),
            ('Bake until it sounds hollow underneath.',
             'ከሥሩ ባዶ ድምፅ እስኪያሰማ ይጋግሩ።', 2400),
        ],
    },
}

# Which design dishes get full ingredient and step lists written here.
DESIGN_DETAIL = {
    'shiro': {
        'region': 'amhara', 'category': 'fasting', 'heat': 2,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('Ground chickpea flour cooked into a loose, savoury stew. The '
                  'dish most often described as the everyday meal -- fast to '
                  'make, and eaten across the country in both fasting and '
                  'non-fasting versions.'),
        'storyAm': ('የተፈጨ የሽምብራ ዱቄት ተቀቅሎ የሚሠራ ወጥ ነው። በየቀኑ የሚበላ ምግብ ተብሎ '
                    'የሚጠራው ሲሆን በፍጥነት ይዘጋጃል፤ በጾምና ከጾም ውጭ በሁለቱም ይሠራል።'),
        'ingredients': [
            ing('Shiro powder', 'የሽሮ ዱቄት', 1, 'cup', 'ኩባያ', PANTRY),
            ing('Onion', 'ሽንኩርት', 1, 'large', 'ትልቅ', FRESH),
            ing('Garlic', 'ነጭ ሽንኩርት', 4, 'cloves', 'ቅንጣት', FRESH),
            ing('Oil', 'ዘይት', 0.25, 'cup', 'ኩባያ', PANTRY),
            ing('Water', 'ውሃ', 3, 'cups', 'ኩባያ', PANTRY),
            ing('Berbere', 'በርበሬ', 1, 'tbsp', 'የሾርባ ማንኪያ', SPICE, True),
        ],
        'steps': [
            ('Dice the onion fine and cook it down in oil.',
             'ሽንኩርቱን በጥሩ ከትፈው በዘይት ያብስሉት።', 600),
            ('Add crushed garlic and cook another minute.',
             'የተወቀጠ ነጭ ሽንኩርት ጨምረው አንድ ደቂቃ ያብስሉ።', 60),
            ('Whisk the shiro powder into cold water until smooth.',
             'የሽሮ ዱቄቱን በቀዝቃዛ ውሃ ለስላሳ እስኪሆን ያማስሉ።', 120),
            ('Pour it in slowly, stirring the whole time.',
             'እያማሰሉ ቀስ ብለው ያፍሱት።', 180),
            ('Simmer until it thickens and loses its raw taste.',
             'እስኪወፍርና ጥሬነቱ እስኪለቅ ያንተከትኩ።', 900),
        ],
    },
    'tibs': {
        'region': 'amhara', 'category': 'tibs', 'heat': 3,
        'fasting': False, 'vegan': False, 'gf': True, 'df': False,
        'story': ('Meat cut small and seared hard and fast, often finished at '
                  'the table on a clay brazier so it keeps sizzling while it is '
                  'eaten.'),
        'storyAm': ('ሥጋው ትንሽ ተቆርጦ በከፍተኛ እሳት በፍጥነት ይጠበሳል፤ ብዙ ጊዜ በሸክላ ምድጃ ላይ '
                    'እየተንተከተከ ማዕድ ላይ ይቀርባል።'),
        'ingredients': [
            ing('Beef, cubed', 'የተከተፈ የበሬ ሥጋ', 700, 'g', 'ግራም', MEAT),
            ing('Onion', 'ሽንኩርት', 1, 'large', 'ትልቅ', FRESH),
            ing('Rosemary', 'ጽጌረዳ', 2, 'sprigs', 'ቅርንጫፍ', FRESH),
            ing('Niter kibbeh', 'ንጥር ቅቤ', 3, 'tbsp', 'የሾርባ ማንኪያ', MEAT),
            ing('Green chilli', 'ቃሪያ', 2, '', '', FRESH),
            ing('Awaze', 'አዋዜ', 2, 'tbsp', 'የሾርባ ማንኪያ', SPICE, True),
        ],
        'steps': [
            ('Get the pan hot enough that the meat hisses on contact.',
             'ሥጋው ሲነካ ድምፅ እስኪያሰማ ድስቱን ያሙቁት።', 300),
            ('Sear the beef in batches. Crowding it will steam it.',
             'ሥጋውን በየተራ ይጥበሱ። ቢበዛ በእንፋሎት ይበስላል።', 480),
            ('Add kibbeh, onion, rosemary and chilli.',
             'ቅቤ፣ ሽንኩርት፣ ጽጌረዳና ቃሪያ ይጨምሩ።', 240),
            ('Toss until the onion is just softened, no further.',
             'ሽንኩርቱ ልክ እስኪለሰልስ ብቻ ያማስሉ።', 180),
        ],
    },
    'misir': {
        'region': 'amhara', 'category': 'fasting', 'heat': 3,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('Red lentils cooked down with berbere until they hold their '
                  'shape on the spoon. A fasting-table anchor.'),
        'storyAm': ('ቀይ ምስር በበርበሬ ተብስሎ በማንኪያ ላይ እስኪቆም ድረስ ይበስላል። የጾም ማዕድ '
                    'ዋነኛ ምግብ ነው።'),
        'ingredients': [
            ing('Red lentils', 'ቀይ ምስር', 2, 'cups', 'ኩባያ', PANTRY),
            ing('Onion', 'ሽንኩርት', 2, '', '', FRESH),
            ing('Berbere', 'በርበሬ', 0.25, 'cup', 'ኩባያ', SPICE),
            ing('Garlic', 'ነጭ ሽንኩርት', 4, 'cloves', 'ቅንጣት', FRESH),
            ing('Oil', 'ዘይት', 0.33, 'cup', 'ኩባያ', PANTRY),
        ],
        'steps': [
            ('Rinse the lentils until the water runs clear.',
             'ምስሩን ውሃው እስኪጠራ ያጠቡት።', 180),
            ('Dry-cook the onions until they collapse and darken.',
             'ሽንኩርቱን እስኪለሰልስና እስኪጠቁር በደረቁ ያብስሉ።', 720),
            ('Add oil and berbere and cook the spice out.',
             'ዘይትና በርበሬ ጨምረው ቅመሙን ያብስሉት።', 480),
            ('Add lentils and water; simmer until thick.',
             'ምስርና ውሃ ጨምረው እስኪወፍር ያንተከትኩ።', 1800),
        ],
    },
    'gomen': {
        'region': 'gurage', 'category': 'fasting', 'heat': 1,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('Collard greens cooked slowly with ginger and garlic until '
                  'they give up their bite.'),
        'storyAm': ('ጎመን ከዝንጅብልና ከነጭ ሽንኩርት ጋር ጠንካራነቱን እስኪለቅ ድረስ በእርጋታ ይበስላል።'),
        'ingredients': [
            ing('Collard greens', 'ጎመን', 1, 'bunch', 'ነዶ', FRESH),
            ing('Onion', 'ሽንኩርት', 1, '', '', FRESH),
            ing('Ginger', 'ዝንጅብል', 1, 'in', 'ኢንች', FRESH),
            ing('Garlic', 'ነጭ ሽንኩርት', 4, 'cloves', 'ቅንጣት', FRESH),
            ing('Oil', 'ዘይት', 3, 'tbsp', 'የሾርባ ማንኪያ', PANTRY),
        ],
        'steps': [
            ('Strip the leaves from the stems and shred them.',
             'ቅጠሉን ከግንዱ ለይተው ይከትፉት።', 300),
            ('Blanch briefly, then drain well.',
             'ለአጭር ጊዜ አፍልተው በደንብ ያጣሩት።', 300),
            ('Soften onion, ginger and garlic in oil.',
             'ሽንኩርት፣ ዝንጅብልና ነጭ ሽንኩርት በዘይት ያለሰልሱ።', 420),
            ('Add the greens and cook down slowly.',
             'ጎመኑን ጨምረው በእርጋታ ያብስሉት።', 1200),
        ],
    },
    'kitfo': {
        'region': 'gurage', 'category': 'raw', 'heat': 4,
        'fasting': False, 'vegan': False, 'gf': True, 'df': False,
        'story': ('Beef minced very fine and warmed -- not cooked -- through '
                  'spiced butter and mitmita. Associated with Gurage cooking, '
                  'and traditionally eaten the day the animal is slaughtered.'),
        'storyAm': ('ሥጋው በጣም በጥሩ ተከትፎ በቅመም ቅቤና በሚጥሚጣ ይሞቃል እንጂ አይበስልም። '
                    'ከጉራጌ ምግብ ጋር የተያያዘ ሲሆን በባህሉ እንስሳው በታረደበት ቀን ይበላል።'),
        'ingredients': [
            ing('Beef, very lean', 'በጣም ቀጭን የበሬ ሥጋ', 600, 'g', 'ግራም', MEAT),
            ing('Niter kibbeh', 'ንጥር ቅቤ', 0.33, 'cup', 'ኩባያ', MEAT),
            ing('Mitmita', 'ሚጥሚጣ', 2, 'tbsp', 'የሾርባ ማንኪያ', SPICE),
            ing('Ayib', 'አይብ', 200, 'g', 'ግራም', MEAT, True),
            ing('Gomen', 'ጎመን', 1, 'cup', 'ኩባያ', FRESH, True),
        ],
        'steps': [
            ('Mince the beef by hand, as fine as you can manage.',
             'ሥጋውን በእጅ በተቻለ መጠን በጥሩ ይክተፉት።', 900),
            ('Warm the kibbeh until it is liquid but not hot.',
             'ቅቤውን እስኪቀልጥ ያሙቁት፤ ግን አይሞቅ።', 180),
            ('Work the kibbeh and mitmita through the meat.',
             'ቅቤውንና ሚጥሚጣውን ከሥጋው ጋር ያዋህዱ።', 300),
            ('Serve at once, with ayib and gomen alongside.',
             'ወዲያውኑ ከአይብና ከጎመን ጋር ያቅርቡ።', None),
        ],
    },
    'firfir': {
        'region': 'amhara', 'category': 'breakfast', 'heat': 3,
        'fasting': True, 'vegan': True, 'gf': False, 'df': True,
        'story': ('Injera torn up and stirred through a spiced sauce -- the dish '
                  'that turns yesterday\'s bread into today\'s breakfast.'),
        'storyAm': ('እንጀራ ተቀዶ በቅመም መረቅ ይቀላቀላል -- የትናንቱን እንጀራ የዛሬ ቁርስ '
                    'የሚያደርግ ምግብ ነው።'),
        'ingredients': [
            ing('Injera', 'እንጀራ', 3, '', '', PANTRY),
            ing('Onion', 'ሽንኩርት', 1, '', '', FRESH),
            ing('Berbere', 'በርበሬ', 2, 'tbsp', 'የሾርባ ማንኪያ', SPICE),
            ing('Oil', 'ዘይት', 3, 'tbsp', 'የሾርባ ማንኪያ', PANTRY),
            ing('Tomato', 'ቲማቲም', 1, '', '', FRESH),
        ],
        'steps': [
            ('Tear the injera into small pieces.',
             'እንጀራውን ትንንሽ አድርገው ይቀዱት።', 180),
            ('Cook onion in oil, then add berbere and tomato.',
             'ሽንኩርቱን በዘይት አብስለው በርበሬና ቲማቲም ይጨምሩ።', 480),
            ('Toss the torn injera through until evenly coated.',
             'የተቀደደውን እንጀራ እኩል እስኪለበስ ይቀላቅሉ።', 240),
        ],
    },
    'kik': {
        'region': 'amhara', 'category': 'fasting', 'heat': 0,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('Yellow split peas cooked with turmeric and no chilli -- the '
                  'mild dish on a fasting plate that otherwise runs hot.'),
        'storyAm': ('ክክ በእርድ ተብስሎ ያለ በርበሬ ይሠራል -- በሌላው ሁሉ በሚያቃጥል የጾም ማዕድ ላይ '
                    'ለስላሳው ምግብ ነው።'),
        'ingredients': [
            ing('Yellow split peas', 'ክክ', 2, 'cups', 'ኩባያ', PANTRY),
            ing('Onion', 'ሽንኩርት', 1, '', '', FRESH),
            ing('Turmeric', 'እርድ', 1, 'tsp', 'የሻይ ማንኪያ', SPICE),
            ing('Garlic', 'ነጭ ሽንኩርት', 3, 'cloves', 'ቅንጣት', FRESH),
            ing('Oil', 'ዘይት', 0.25, 'cup', 'ኩባያ', PANTRY),
        ],
        'steps': [
            ('Soak the split peas, then rinse them.',
             'ክኩን አጥልቀው ያጠቡት።', 1800),
            ('Soften onion in oil with turmeric and garlic.',
             'ሽንኩርቱን ከእርድና ከነጭ ሽንኩርት ጋር በዘይት ያለሰልሱ።', 420),
            ('Add peas and water; simmer until they break down.',
             'ክክና ውሃ ጨምረው እስኪፈርስ ያንተከትኩ።', 2400),
        ],
    },
    'dulet': {
        'region': 'gurage', 'category': 'raw', 'heat': 4,
        'fasting': False, 'vegan': False, 'gf': True, 'df': False,
        'story': ('Finely chopped tripe, liver and lean meat, warmed through '
                  'spiced butter and mitmita. Ordered by people who know '
                  'exactly what they want.'),
        'storyAm': ('ጨጓራ፣ ጉበትና ቀጭን ሥጋ በጥሩ ተከትፎ በቅመም ቅቤና በሚጥሚጣ ይሞቃል። '
                    'የሚፈልጉትን በትክክል በሚያውቁ ሰዎች ይታዘዛል።'),
        'ingredients': [
            ing('Tripe', 'ጨጓራ', 300, 'g', 'ግራም', MEAT),
            ing('Liver', 'ጉበት', 200, 'g', 'ግራም', MEAT),
            ing('Lean beef', 'ቀጭን ሥጋ', 200, 'g', 'ግራም', MEAT),
            ing('Niter kibbeh', 'ንጥር ቅቤ', 0.25, 'cup', 'ኩባያ', MEAT),
            ing('Mitmita', 'ሚጥሚጣ', 2, 'tbsp', 'የሾርባ ማንኪያ', SPICE),
            ing('Onion', 'ሽንኩርት', 1, '', '', FRESH),
        ],
        'steps': [
            ('Clean the tripe thoroughly and chop everything very fine.',
             'ጨጓራውን በደንብ አጽድተው ሁሉንም በጣም በጥሩ ይክተፉ።', 1200),
            ('Warm the kibbeh with onion until fragrant.',
             'ቅቤውን ከሽንኩርት ጋር ሽታው እስኪወጣ ያሙቁት።', 300),
            ('Add the meats and warm through briefly.',
             'ሥጋዎቹን ጨምረው ለአጭር ጊዜ ያሙቁ።', 240),
            ('Stir in mitmita and serve immediately.',
             'ሚጥሚጣ ጨምረው ወዲያውኑ ያቅርቡ።', None),
        ],
    },
    'buna': {
        'region': 'sidama', 'category': 'ceremony', 'heat': 0,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('The coffee ceremony: green beans roasted, ground and brewed '
                  'in front of the people who will drink them, served in three '
                  'rounds. It is not a fast process, and it is not meant to be.'),
        'storyAm': ('የቡና ሥነ ሥርዓት፡ ጥሬ ቡና በሚጠጡት ሰዎች ፊት ተቁሎ፣ ተፈጭቶና ተፈልቶ በሦስት '
                    'ዙር ይቀርባል። ፈጣን ሂደት አይደለም፤ እንዲሆንም አልታሰበም።'),
        'ingredients': [
            ing('Green coffee beans', 'ጥሬ ቡና', 1, 'cup', 'ኩባያ', PANTRY),
            ing('Water', 'ውሃ', 4, 'cups', 'ኩባያ', PANTRY),
            ing('Incense', 'ዕጣን', 1, 'piece', 'ቁራጭ', PANTRY, True),
            ing('Sugar', 'ስኳር', 0, 'to taste', 'እንደ አስፈላጊነቱ', PANTRY, True),
        ],
        'steps': [
            ('Wash the green beans and set the incense burning.',
             'ጥሬ ቡናውን አጥበው ዕጣኑን ያጭሱ።', 300),
            ('Roast the beans in a flat pan, shaking constantly.',
             'ቡናውን በጠፍጣፋ ምጣድ እያወዛወዙ ይቁሉት።', 900),
            ('Carry the pan around so everyone takes the smoke.',
             'ሁሉም ጭሱን እንዲያገኝ ምጣዱን ያዙሩት።', 120),
            ('Grind the roasted beans by hand.',
             'የተቆላውን ቡና በእጅ ይፍጩት።', 600),
            ('Brew in the jebena and let it rise without boiling over.',
             'በጀበና አፍልተው ሳይፈስ እንዲወጣ ያድርጉ።', 900),
            ('Pour the first round from a height, in one go.',
             'የመጀመሪያውን ዙር ከከፍታ በአንድ ጊዜ ያፍሱ።', None),
        ],
    },
    'beyay': {
        'region': 'amhara', 'category': 'fasting', 'heat': 3,
        'fasting': True, 'vegan': True, 'gf': False, 'df': True,
        'story': ('Not one dish but a plate of them -- shiro, misir, gomen, kik '
                  'and more, arranged on injera so no two mouthfuls are the '
                  'same. The fasting table at its fullest.'),
        'storyAm': ('አንድ ምግብ ሳይሆን የብዙ ምግቦች ማዕድ ነው -- ሽሮ፣ ምስር፣ ጎመን፣ ክክና ሌሎችም '
                    'በእንጀራ ላይ ተደርድረው ሁለት ጉርሻ አንድ ዓይነት እንዳይሆን። የጾም ማዕድ '
                    'በሙላቱ።'),
        'ingredients': [
            ing('Injera', 'እንጀራ', 4, 'large', 'ትልቅ', PANTRY),
            ing('Shiro', 'ሽሮ', 1, 'portion', 'ድርሻ', PANTRY),
            ing('Misir wat', 'ምስር ወጥ', 1, 'portion', 'ድርሻ', PANTRY),
            ing('Gomen', 'ጎመን', 1, 'portion', 'ድርሻ', FRESH),
            ing('Kik alicha', 'ክክ አልጫ', 1, 'portion', 'ድርሻ', PANTRY),
            ing('Atakilt', 'አትክልት', 1, 'portion', 'ድርሻ', FRESH),
            ing('Fosolia', 'ፎሶሊያ', 1, 'portion', 'ድርሻ', FRESH),
        ],
        'steps': [
            ('Plan backwards from serving time -- the slow dishes start first.',
             'ከማቅረቢያ ሰዓት ወደኋላ ያቅዱ -- ዘገምተኛዎቹ መጀመሪያ ይጀምራሉ።', None),
            ('Start misir and kik, which take the longest.',
             'ረጅም ጊዜ የሚወስዱትን ምስርና ክክ ይጀምሩ።', 2400),
            ('Cook gomen and atakilt while those simmer.',
             'እነሱ እየተንተከተኩ ጎመንና አትክልት ያብስሉ።', 1800),
            ('Make the shiro last, so it is still loose.',
             'ሽሮውን መጨረሻ ይሥሩ፤ እንዳይወፍር።', 900),
            ('Lay injera and spoon each dish into its own place.',
             'እንጀራ አንጥፈው እያንዳንዱን ምግብ በየቦታው ያድርጉ።', 300),
        ],
    },
    'injera': {
        'region': 'amhara', 'category': 'bread', 'heat': 0,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'story': ('Teff batter left to ferment for days, then poured in a spiral '
                  'onto a hot mitad. The sourness comes from time, not from an '
                  'ingredient -- which is why it cannot be hurried.'),
        'storyAm': ('የጤፍ ሊጥ ለቀናት ካሸተ በኋላ በሙቅ ምጣድ ላይ በጥቅል ይፈስሳል። ጎምዛዛነቱ '
                    'ከጊዜ እንጂ ከግብዓት አይመጣም -- ስለዚህ ማፋጠን አይቻልም።'),
        'ingredients': [
            ing('Teff flour', 'የጤፍ ዱቄት', 4, 'cups', 'ኩባያ', PANTRY),
            ing('Water', 'ውሃ', 5, 'cups', 'ኩባያ', PANTRY),
            ing('Ersho (starter)', 'እርሾ', 0.5, 'cup', 'ኩባያ', PANTRY, True),
        ],
        'steps': [
            ('Mix teff flour and water into a smooth batter.',
             'የጤፍ ዱቄትና ውሃ አዋህደው ለስላሳ ሊጥ ያድርጉ።', 600),
            ('Cover loosely and leave it to ferment. Day one.',
             'በላላ ሸፍነው እንዲያሽት ይተዉት። አንደኛ ቀን።', None),
            ('Day two: it should smell sour and show bubbles.',
             'ሁለተኛ ቀን፡ ጎምዛዛ ሽታና አረፋ ሊኖረው ይገባል።', None),
            ('Day three: pour off the water that has risen on top.',
             'ሦስተኛ ቀን፡ ላይ የወጣውን ውሃ ያፍስሱ።', None),
            ('Cook a little absit, stir it back in, rest an hour.',
             'ትንሽ አብሲት አብስለው መልሰው ይቀላቅሉና አንድ ሰዓት ያሳርፉ።', 3600),
            ('Pour in a spiral from the outside in onto a hot mitad.',
             'በሙቅ ምጣድ ላይ ከዳር ወደ መሃል በጥቅል ያፍሱ።', 180),
            ('Cover until the eyes set. Do not turn it.',
             'ዓይኖቹ እስኪበስሉ ይሸፍኑ። አይገለብጡት።', 180),
        ],
    },
}

REGION_MAP = {
    'Gurage': 'gurage', 'Amhara': 'amhara', 'Tigray': 'tigray',
    'Oromia': 'oromia', 'Harar': 'harar', 'Sidama': 'sidama',
    'Afar': 'afar', 'Somali': 'somali',
}


def main():
    with open(DESIGN, encoding='utf-8') as fh:
        design = json.load(fh)

    recipes = {}

    # --- the design's 12 dishes -------------------------------------------
    for key, dish in design['dishes'].items():
        detail = DESIGN_DETAIL.get(key, {})

        if key == 'doro':
            # Doro Wat is fully specified in the design itself.
            ingredients = [
                ing(i['en'], i['am'], q, u, ua, aisle)
                for i, (q, u, ua, aisle) in zip(
                    design['doroWatIngredients'],
                    [(4, 'large', 'ትልቅ', FRESH), (0.5, 'cup', 'ኩባያ', MEAT),
                     (0.75, 'cup', 'ኩባያ', SPICE), (1.5, 'kg', 'ኪ.ግ', MEAT),
                     (8, 'cloves', 'ቅንጣት', FRESH), (2, 'in', 'ኢንች', FRESH),
                     (6, '', '', MEAT), (1, '', '', FRESH)])
            ]
            durations = [None, 900, 180, 480, 120, 300, 2700, 120, 600]
            steps = [
                step(n, s['en'], s['am'], durations[n])
                for n, s in enumerate(design['doroWatSteps'])
            ]
            steps[1]['tip'] = 'No oil until the onions give up their water.'
            steps[1]['tipAm'] = 'ሽንኩርቱ ውሃውን እስኪለቅ ዘይት የለም።'
            detail = {
                'region': 'amhara', 'category': 'wat', 'heat': 4,
                'fasting': False, 'vegan': False, 'gf': True, 'df': False,
                'story': ('Doro wat is what you make when someone is worth a '
                          'whole day. Four onions, cooked dry until they give up '
                          'their water -- that is the whole secret, and it cannot '
                          'be hurried. In much of Ethiopia it is the dish that '
                          'ends a fast, carried to the table whole, the eggs '
                          'scored so the sauce gets inside.'),
                'storyAm': ('ዶሮ ወጥ የሚሠራው አንድ ሰው ሙሉ ቀን የሚያስወጣ ሲሆን ነው። አራት ሽንኩርት፣ '
                            'ውሃቸውን እስኪለቁ ድረስ በደረቁ ይበስላሉ -- ሚስጥሩ ይህ ብቻ ነው፣ '
                            'ማፋጠንም አይቻልም። በአብዛኛው ኢትዮጵያ ጾም የሚፈታበት ምግብ ነው፤ '
                            'እንቁላሎቹ ወጡ እንዲገባባቸው ተተልትለው ይቀርባሉ።'),
            }
        else:
            ingredients = detail.get('ingredients', [])
            steps = [
                step(n, s[0], s[1], s[2])
                for n, s in enumerate(detail.get('steps', []))
            ]

        recipes[key] = {
            'title': dish['en'], 'titleAm': dish['am'],
            'subtitle': dish['se'], 'subtitleAm': dish['sa'],
            'story': detail.get('story', ''), 'storyAm': detail.get('storyAm', ''),
            'regionId': detail.get('region', 'amhara'),
            'category': detail.get('category', 'wat'),
            'difficulty': ['Beginner', 'Medium', 'Advanced'].index(dish['lv'][0]),
            'totalMinutes': dish['min'], 'servings': 6, 'xpReward': dish['xp'],
            'heatLevel': detail.get('heat', 2),
            'tags': [detail.get('category', 'wat'), detail.get('region', 'amhara')],
            'ingredients': ingredients, 'equipment': [], 'steps': steps,
            'gradientA': dish['a'], 'gradientB': dish['b'],
            'isFasting': detail.get('fasting', False),
            'isVegan': detail.get('vegan', False),
            'isGlutenFree': detail.get('gf', False),
            'isDairyFree': detail.get('df', False),
            'isTraditional': True, 'isFamilyRecipe': False,
            'averageRating': 0.0, 'ratingCount': 0, 'numberOfCooks': 0,
        }

    # --- the extras --------------------------------------------------------
    for key, dish in EXTRA.items():
        recipes[key] = {
            'title': dish['en'], 'titleAm': dish['am'],
            'subtitle': dish['se'], 'subtitleAm': dish['sa'],
            'story': dish['story'], 'storyAm': dish['storyAm'],
            'regionId': dish['region'], 'category': dish['category'],
            'difficulty': dish['lv'], 'totalMinutes': dish['min'],
            'servings': 6, 'xpReward': dish['xp'], 'heatLevel': dish['heat'],
            'tags': [dish['category'], dish['region']],
            'ingredients': dish['ingredients'], 'equipment': [],
            'steps': [step(n, s[0], s[1], s[2])
                      for n, s in enumerate(dish['steps'])],
            'gradientA': dish['a'], 'gradientB': dish['b'],
            'isFasting': dish['fasting'], 'isVegan': dish['vegan'],
            'isGlutenFree': dish['gf'], 'isDairyFree': dish['df'],
            'isTraditional': True, 'isFamilyRecipe': False,
            'averageRating': 0.0, 'ratingCount': 0, 'numberOfCooks': 0,
        }

    regions = [
        {
            'id': REGION_MAP[r['en']], 'name': r['en'], 'nameAm': r['am'],
            'gradientA': r['colorA'], 'gradientB': r['colorB'], 'order': n,
        }
        for n, r in enumerate(design['regions'])
    ]

    payload = {'recipes': recipes, 'regions': regions}
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as fh:
        json.dump(payload, fh, ensure_ascii=False, indent=1)
        fh.write('\n')

    detailed = sum(1 for r in recipes.values() if r['steps'])
    print('%s' % os.path.relpath(OUT, ROOT))
    print('  %d recipes (%d from the design, %d added), %d with full steps'
          % (len(recipes), len(design['dishes']), len(EXTRA), detailed))
    print('  %d regions' % len(regions))
    total_steps = sum(len(r['steps']) for r in recipes.values())
    total_ings = sum(len(r['ingredients']) for r in recipes.values())
    print('  %d steps, %d ingredient lines total' % (total_steps, total_ings))


if __name__ == '__main__':
    main()
