#!/usr/bin/env python3
"""Generates seed/ingredients.json and seed/recipes.json for Rasoi.
Run from repo root: python3 tools/gen_seed.py  (also validates cross-references)."""
import json, os, sys

# ---------------------------------------------------------------- ingredients
# (name, aliases, category, unit, shelfDays, staple, storeKind, tags, flags, quickSnack)
# flags: e=egg d=dairy n=nuts g=gluten
I = []
def ing(name, cat, unit="g", shelf=7, staple=False, store="supermarket", tags=(), aliases=(), flags="", snack=False):
    I.append(dict(name=name, aliases=list(aliases), category=cat, defaultUnit=unit,
                  typicalShelfLifeDays=shelf, isStaple=staple, defaultStoreKind=store,
                  nutritionTags=list(tags), containsEgg="e" in flags, containsDairy="d" in flags,
                  containsNuts="n" in flags, containsGluten="g" in flags, isQuickHealthySnack=snack))

# fruit
for n,a,sh,st in [("Apple",("apples",),21,True),("Banana",("bananas",),6,True),("Orange",("oranges","clementine"),14,False),
    ("Grapes",(),7,False),("Strawberries",("strawberry",),4,False),("Blueberries",("blueberry",),7,False),
    ("Mango",("mangoes",),6,False),("Watermelon",(),5,False),("Pear",("pears",),10,False),("Kiwi",(),10,False),
    ("Pomegranate",("anar",),21,False),("Papaya",(),5,False),("Avocado",("avocados",),5,False),("Lemon",("lemons","nimbu"),21,True),
    ("Lime",("limes",),21,False),("Dates",("khajur",),180,False),("Raisins",("kishmish",),180,False),("Frozen mixed berries",("frozen berries",),180,False)]:
    ing(n,"fruit","count",sh,st,"supermarket",("fruit","vitaminC","fibre"),a,"",True)
# vegetables
for n,a,sh,st in [("Potato",("potatoes","aloo"),21,True),("Onion",("onions","pyaz"),21,True),("Tomato",("tomatoes","tamatar"),7,True),
    ("Carrot",("carrots","gajar"),21,True),("Cucumber",("cucumbers","kheera"),7,True),("Bell pepper",("capsicum","shimla mirch","peppers"),10,False),
    ("Cauliflower",("gobi","phool gobi"),10,False),("Broccoli",(),7,False),("Green beans",("beans","french beans"),7,False),
    ("Peas",("green peas","matar"),5,False),("Sweet potato",("shakarkandi",),21,False),("Zucchini",("courgette",),7,False),
    ("Corn",("sweet corn","corn on the cob"),5,False),("Cabbage",("patta gobi",),14,False),("Bottle gourd",("lauki","dudhi","ghia"),10,False),
    ("Okra",("bhindi","lady finger"),5,False),("Eggplant",("baingan","brinjal","aubergine"),7,False),("Pumpkin",("kaddu","butternut squash"),21,False),
    ("Mushrooms",("mushroom",),5,False),("Beetroot",("beet","beets","chukandar"),21,False),("Green chili",("hari mirch","chillies"),10,False),
    ("Ginger",("adrak",),21,True),("Garlic",("lehsun",),30,True),("Celery",(),10,False),("Radish",("mooli",),10,False)]:
    ing(n,"vegetable","count",sh,st,"supermarket",("vegetable","fibre","vitaminA" if n in("Carrot","Sweet potato","Pumpkin") else "vitaminC"),a,"",n in("Carrot","Cucumber","Bell pepper"))
for n,a in [("Spinach",("palak","baby spinach")),("Methi leaves",("fenugreek leaves","methi")),("Cilantro",("coriander leaves","dhania","coriander")),
    ("Mint",("pudina",)),("Lettuce",("romaine","salad leaves")),("Kale",()),("Curry leaves",("kadi patta",))]:
    ing(n,"leafyGreen","bunch",4,n in("Spinach","Cilantro"),"supermarket",("vegetable","iron","vitaminA","fibre"),a)
# dairy & egg & soy
for n,a,sh,st,tags,fl in [("Milk",("whole milk","doodh"),7,True,("calcium","protein"),"d"),("Plain yogurt",("dahi","curd","yogurt"),14,True,("calcium","protein"),"d"),
    ("Greek yogurt",(),14,False,("calcium","protein"),"d"),("Paneer",("cottage cheese",),7,True,("protein","calcium"),"d"),
    ("Cheddar cheese",("cheese","shredded cheese"),21,True,("calcium","protein"),"d"),("Mozzarella",("mozzarella cheese",),14,False,("calcium","protein"),"d"),
    ("Parmesan",(),30,False,("calcium",),"d"),("Butter",("makhan",),60,True,("healthyFat",),"d"),("Ghee",(),180,True,("healthyFat",),"d"),
    ("Cream cheese",(),21,False,("calcium",),"d"),("Sour cream",(),14,False,("calcium",),"d"),("Ricotta",(),7,False,("protein","calcium"),"d")]:
    ing(n,"dairy","g" if n not in("Milk",) else "ml",sh,st,"supermarket",tags,a,fl,n in("Plain yogurt","Greek yogurt","Cheddar cheese"))
ing("Eggs","egg","count",21,True,"supermarket",("protein",),("egg",),"e")
ing("Firm tofu","legume","g",10,False,"eastAsian",("protein","calcium","iron"),("tofu",))
ing("Edamame","legume","g",180,False,"eastAsian",("protein","fibre","iron"),("frozen edamame",),"",True)
# legumes
for n,a in [("Toor dal",("arhar dal","split pigeon peas","tuvar dal")),("Moong dal",("yellow moong dal","split mung")),("Whole green moong",("green moong","mung beans","sabut moong")),
    ("Masoor dal",("red lentils","malka masoor")),("Chana dal",("split chickpeas",)),("Urad dal",("black gram","white urad")),
    ("Rajma",("kidney beans","red kidney beans")),("Chickpeas",("chole","kabuli chana","garbanzo")),("Kala chana",("black chickpeas",)),
    ("Black beans",()),("Pinto beans",()),("Roasted chana",("bhuna chana",)),("Hummus",()),("Sprouted moong",("sprouts",))]:
    ing(n,"legume","g",7 if n in("Hummus","Sprouted moong") else 365,n in("Toor dal","Moong dal","Chickpeas"),"indian" if "dal" in n.lower() or n in("Rajma","Kala chana","Roasted chana","Whole green moong") else "supermarket",("protein","iron","fibre"),a,"",n in("Roasted chana","Hummus"))
# grains
for n,a,st,store,tags,fl in [("Basmati rice",("rice","chawal"),True,"indian",("grain",),""),("Brown rice",(),False,"supermarket",("grain","wholeGrain","fibre"),""),
    ("Poha",("flattened rice","beaten rice"),False,"indian",("grain","iron"),""),("Sooji",("rava","semolina"),False,"indian",("grain",),"g"),
    ("Rolled oats",("oats","oatmeal"),True,"supermarket",("grain","wholeGrain","fibre"),""),("Quinoa",(),False,"supermarket",("grain","wholeGrain","protein"),""),
    ("Daliya",("broken wheat","bulgur","cracked wheat"),False,"indian",("grain","wholeGrain","fibre"),"g"),("Pasta",("penne","spaghetti","macaroni"),True,"supermarket",("grain",),"g"),
    ("Whole wheat pasta",(),False,"supermarket",("grain","wholeGrain","fibre"),"g"),("Idli rice",(),False,"indian",("grain",),""),
    ("Vermicelli",("semiya","seviyan"),False,"indian",("grain",),"g"),("Sabudana",("tapioca pearls",),False,"indian",("grain",),""),
    ("Millet",("bajra","ragi","foxtail millet"),False,"indian",("grain","wholeGrain","iron"),""),("Couscous",(),False,"supermarket",("grain",),"g"),
    ("Rice noodles",(),False,"eastAsian",("grain",),""),("Cornflakes",(),False,"supermarket",("grain",),"g")]:
    ing(n,"grain","g",365,st,store,tags,a,fl)
for n,a,st,store,fl in [("Atta",("whole wheat flour","chapati flour"),True,"indian","g"),("Besan",("gram flour","chickpea flour"),False,"indian",""),
    ("All-purpose flour",("maida","flour"),False,"supermarket","g"),("Whole wheat bread",("bread","sandwich bread"),True,"supermarket","g"),
    ("Whole wheat tortillas",("tortillas","wraps"),False,"hispanic","g"),("Corn tortillas",(),False,"hispanic",""),("Pita bread",(),False,"supermarket","g"),
    ("Pizza dough",(),False,"supermarket","g"),("Bread crumbs",("panko",),False,"supermarket","g"),("Rice flour",(),False,"indian",""),
    ("Ragi flour",("finger millet flour","nachni"),False,"indian",""),("Pav buns",("dinner rolls","burger buns"),False,"supermarket","g"),
    ("Naan",(),False,"indian","g"),("Baking powder",(),False,"supermarket",""),("Baking soda",(),False,"supermarket","")]:
    ing(n,"flourBread","g",7 if n in("Whole wheat bread","Whole wheat tortillas","Corn tortillas","Pita bread","Pizza dough","Pav buns","Naan") else 180,st,store,("grain","wholeGrain") if "wheat" in n.lower() or "Ragi" in n else ("grain",),a,fl)
# nuts & seeds
for n,a,fl,tags in [("Almonds",("badam",),"n",("protein","healthyFat")),("Cashews",("kaju",),"n",("healthyFat",)),("Peanuts",("moongphali","groundnut"),"n",("protein","healthyFat")),
    ("Peanut butter",(),"n",("protein","healthyFat")),("Almond butter",(),"n",("protein","healthyFat")),("Walnuts",("akhrot",),"n",("healthyFat",)),
    ("Chia seeds",(),"",("fibre","healthyFat","calcium")),("Flax seeds",("alsi",),"",("fibre","healthyFat")),("Sesame seeds",("til",),"",("calcium","iron")),
    ("Pumpkin seeds",(),"",("iron","protein")),("Sunflower seeds",(),"",("healthyFat",)),("Makhana",("fox nuts","lotus seeds"),"",("protein",)),
    ("Shredded coconut",("desiccated coconut","coconut"),"",("healthyFat",))]:
    ing(n,"nutSeed","g",180,False,"supermarket",tags,a,fl,n in("Almonds","Makhana"))
# spices & condiments
for n,a in [("Turmeric",("haldi",)),("Cumin seeds",("jeera",)),("Ground cumin",()),("Coriander powder",("dhania powder",)),("Garam masala",()),
    ("Red chili powder",("lal mirch","cayenne","paprika")),("Mustard seeds",("rai","sarson")),("Asafoetida",("hing",)),("Salt",("namak",)),
    ("Black pepper",("kali mirch",)),("Cinnamon",("dalchini",)),("Cardamom",("elaichi",)),("Chaat masala",()),("Amchur",("dry mango powder",)),
    ("Kasuri methi",("dried fenugreek",)),("Pav bhaji masala",()),("Sambar powder",()),("Italian seasoning",("oregano","dried oregano")),
    ("Taco seasoning",()),("Curry powder",()),("Cumin-coriander (dhana jeera)",("dhana jeera",)),("Vanilla extract",()),("Cocoa powder",()),("Nutmeg",("jaiphal",))]:
    ing(n,"spice","g",365,n in("Turmeric","Cumin seeds","Salt","Garam masala"),"indian" if n not in("Salt","Black pepper","Cinnamon","Italian seasoning","Taco seasoning","Vanilla extract","Cocoa powder") else "supermarket",(),a)
for n,a,fl,tags in [("Olive oil",("extra virgin olive oil",),"",("healthyFat",)),("Vegetable oil",("sunflower oil","canola oil","cooking oil"),"",()),("Coconut oil",(),"",()),
    ("Soy sauce",(),"g",()),("Tomato puree",("tomato sauce","passata"),"",()),("Tomato ketchup",("ketchup",),"",()),("Tamarind paste",("imli",),"",()),
    ("Honey",("shahad",),"",()),("Maple syrup",(),"",()),("Jaggery",("gur",),"",("iron",)),("Sugar",("cheeni",),"",()),("Vinegar",("rice vinegar","white vinegar"),"",()),
    ("Salsa",(),"",("vegetable",)),("Marinara sauce",("pasta sauce",),"",("vegetable",)),("Coconut milk",(),"",("healthyFat",)),("Vegetable stock",("veg broth","bouillon"),"",()),
    ("Mayonnaise",("mayo",),"e",()),("Sriracha",("hot sauce",),"",()),("Sesame oil",(),"",("healthyFat",)),("Pickle",("achar",),"",()),("Cornstarch",("corn flour",),"",())]:
    ing(n,"oilCondiment","ml" if "oil" in n.lower() or n in("Soy sauce","Vinegar","Honey","Maple syrup","Coconut milk","Vegetable stock") else "g",365,n in("Olive oil","Vegetable oil","Salt"),"supermarket",tags,a,fl)
# frozen / snacks / beverages
for n,a,cat,tags,fl,snack,store in [("Frozen peas",(),"frozen",("vegetable","protein","fibre"),"",False,"supermarket"),("Frozen mixed vegetables",("frozen veg",),"frozen",("vegetable",),"",False,"supermarket"),
    ("Frozen corn",(),"frozen",("vegetable",),"",False,"supermarket"),("Frozen spinach",(),"frozen",("vegetable","iron"),"",False,"supermarket"),
    ("Frozen paratha",(),"frozen",("grain",),"g",False,"indian"),("Frozen mango chunks",(),"frozen",("fruit","vitaminC"),"",False,"supermarket"),
    ("Whole grain crackers",("crackers",),"snack",("grain","wholeGrain"),"g",True,"supermarket"),("Rice cakes",(),"snack",("grain",),"",True,"supermarket"),
    ("Popcorn kernels",(),"snack",("grain","wholeGrain","fibre"),"",True,"supermarket"),("Granola",(),"snack",("grain","wholeGrain"),"gn",True,"supermarket"),
    ("Dark chocolate chips",("chocolate chips",),"snack",(),"d",False,"supermarket"),("Khakhra",(),"snack",("grain","wholeGrain"),"g",True,"indian"),
    ("Cheese sticks",("string cheese",),"snack",("calcium","protein"),"d",True,"supermarket"),("Orange juice",(),"beverage",("vitaminC",),"",False,"supermarket"),
    ("Coconut water",(),"beverage",(),"",True,"supermarket"),("Almond milk",(),"beverage",("calcium",),"n",False,"supermarket"),("Oat milk",(),"beverage",("calcium",),"g",False,"supermarket")]:
    ing(n,cat,"g",180,False,store,tags,a,fl,snack)

names = [x["name"] for x in I]
assert len(names) == len(set(names)), "duplicate ingredient"
lookup = {}
for x in I:
    lookup[x["name"].lower()] = x
    for a in x["aliases"]: lookup[a.lower()] = x

# ---------------------------------------------------------------- recipes
R = []
def rec(sid, title, cuisine, meals, appl, prep, cook, servings, minAge, ings, steps, tags, kid, note, lunchbox=False):
    ci = []
    flags = dict(containsEgg=False, containsDairy=False, containsNuts=False, containsGluten=False)
    for it in ings:
        name, qty, unit = it[0], it[1], it[2]
        opt = len(it) > 3 and it[3] == "opt"
        row = lookup.get(name.lower())
        if row is None:
            sys.exit(f"recipe {sid} references unknown ingredient '{name}'")
        if not opt:
            for k in flags: flags[k] = flags[k] or row[k]
        ci.append(dict(ingredientName=row["name"], quantity=qty, unit=unit, isOptional=opt, note=it[4] if len(it) > 4 else ""))
    total = prep + cook
    R.append(dict(seedID=sid, title=title, cuisine=cuisine, mealTypes=meals, appliances=appl, prepMinutes=prep,
                  cookMinutes=cook, servings=servings, minAgeYears=minAge, ingredients=ci, steps=steps,
                  nutritionTags=sorted(set(tags)), isQuick=total <= 15, kidBaseline=kid, kidFriendlyNote=note,
                  lunchboxOK=lunchbox, source="seed", **flags))

B, L, D, S = "breakfast", "lunch", "dinner", "snack"
IP, VM, ST, OV, AF = "instantPot", "vitamix", "stovetop", "oven", "airFryer"

# ---- breakfasts (12)
rec("bf-oats-banana","Banana Peanut-Butter Oatmeal","American",[B],[ST],3,7,4,2,
    [("Rolled oats",160,"g"),("Milk",600,"ml"),("Banana",2,"count"),("Peanut butter",30,"g"),("Cinnamon",1,"g"),("Honey",10,"g","opt")],
    ["Bring milk to a simmer, stir in oats.","Cook 5–6 min, stirring, until creamy.","Mash one banana into the pot; slice the other on top.","Swirl in peanut butter and cinnamon; drizzle honey for the kids."],
    ["wholeGrain","protein","fruit","calcium"],5,"Serve slightly cooled; let kids add their own banana slices.")
rec("bf-poha","Vegetable Poha","Indian",[B,S],[ST],10,10,4,2,
    [("Poha",200,"g"),("Onion",1,"count"),("Potato",1,"count"),("Peas",80,"g"),("Peanuts",30,"g","opt"),("Mustard seeds",3,"g"),("Turmeric",2,"g"),("Curry leaves",1,"bunch","opt"),("Vegetable oil",15,"ml"),("Lemon",1,"count"),("Salt",3,"g"),("Cilantro",1,"bunch","opt")],
    ["Rinse poha in a sieve until soft; drain.","Heat oil; pop mustard seeds, add curry leaves, onion; fry 2 min.","Add diced potato + peas, turmeric, salt; cover 5 min until soft.","Fold in poha, warm 2 min, squeeze lemon, top with cilantro."],
    ["grain","iron","vegetable"],4,"Skip green chili; peanuts on the side for the 4-year-old.")
rec("bf-besan-chilla","Besan Chilla (Savory Chickpea Pancakes)","Indian",[B,L],[ST],5,15,4,2,
    [("Besan",200,"g"),("Onion",1,"count"),("Tomato",1,"count"),("Cilantro",1,"bunch"),("Turmeric",1,"g"),("Salt",3,"g"),("Vegetable oil",15,"ml"),("Plain yogurt",150,"g","opt")],
    ["Whisk besan with 300 ml water, turmeric, salt to a pancake batter.","Stir in finely chopped onion, tomato, cilantro.","Ladle onto a hot oiled pan; cook 2 min each side.","Serve with yogurt for dipping."],
    ["protein","fibre","vegetable"],4,"Make small 'mini pancakes' and let kids dip in yogurt or ketchup.",True)
rec("bf-veg-upma","Vegetable Sooji Upma","Indian",[B],[ST],5,15,4,2,
    [("Sooji",200,"g"),("Onion",1,"count"),("Carrot",1,"count"),("Peas",80,"g"),("Mustard seeds",3,"g"),("Ghee",15,"g"),("Salt",3,"g"),("Ginger",5,"g"),("Curry leaves",1,"bunch","opt")],
    ["Dry-roast sooji 4 min until fragrant; set aside.","Heat ghee; pop mustard seeds, add ginger, onion, curry leaves.","Add carrot, peas and 600 ml water; salt; boil.","Stream in sooji while stirring; cover 3 min off heat."],
    ["grain","vegetable"],3,"Add a spoon of ghee and a squeeze of lemon; kids like it shaped into balls.")
rec("bf-idli","Instant Pot Idli with Coconut Chutney","Indian",[B,S],[IP,VM],10,20,4,1,
    [("Idli rice",300,"g"),("Urad dal",100,"g"),("Salt",4,"g"),("Shredded coconut",60,"g"),("Roasted chana",20,"g"),("Ginger",5,"g")],
    ["(Batter: soak rice + dal 6 h, grind in Vitamix, ferment overnight in Instant Pot on Yogurt mode 8 h.)","Grease idli molds, fill, steam 12 min in Instant Pot (vent open).","Blend coconut, roasted chana, ginger, salt and 100 ml water in Vitamix for chutney.","Serve warm with chutney."],
    ["grain","protein"],5,"Soft, mild, hand-held — a reliable favourite; keep chutney mild.",True)
rec("bf-egg-veg-scramble","Cheesy Veggie Egg Scramble","American",[B],[ST],5,8,4,1,
    [("Eggs",6,"count"),("Bell pepper",1,"count"),("Spinach",1,"bunch"),("Cheddar cheese",60,"g"),("Butter",10,"g"),("Salt",2,"g"),("Whole wheat bread",4,"count")],
    ["Melt butter; soften diced pepper 2 min; wilt spinach 1 min.","Pour in whisked eggs with a pinch of salt; stir gently over low heat.","Fold in cheese when just set.","Serve on toasted bread."],
    ["protein","vegetable","calcium","iron"],4,"Chop veg small; kids can pick 'their' toppings.")
rec("bf-moong-chilla","Moong Dal Chilla with Paneer Filling","Indian",[B,L],[VM,ST],10,15,4,2,
    [("Moong dal",200,"g"),("Paneer",100,"g"),("Ginger",5,"g"),("Cumin seeds",2,"g"),("Salt",3,"g"),("Vegetable oil",15,"ml"),("Cilantro",1,"bunch","opt")],
    ["(Soak moong dal 3 h.) Blend with ginger, cumin, salt and water in Vitamix to a thin batter.","Spread on a hot oiled pan, cook 2 min per side.","Crumble paneer with cilantro; spoon inside and fold."],
    ["protein","iron"],4,"High-protein 'dosa' the kids can roll and eat by hand.",True)
rec("bf-overnight-chia-oats","Overnight Berry Chia Oats","American",[B,S],[],5,0,4,2,
    [("Rolled oats",160,"g"),("Chia seeds",20,"g"),("Milk",500,"ml"),("Plain yogurt",150,"g"),("Frozen mixed berries",150,"g"),("Honey",15,"g","opt")],
    ["Mix oats, chia, milk, yogurt in jars.","Top with berries; refrigerate overnight.","Stir and eat cold or warmed 1 min."],
    ["wholeGrain","fibre","fruit","calcium"],4,"Let each kid build their own jar the night before.",True)
rec("bf-ragi-pancakes","Ragi Banana Pancakes","Indian",[B,S],[ST],5,12,4,1,
    [("Ragi flour",120,"g"),("Atta",60,"g"),("Banana",2,"count"),("Milk",250,"ml"),("Baking powder",4,"g"),("Jaggery",20,"g","opt"),("Ghee",15,"g")],
    ["Mash bananas; whisk with milk and jaggery.","Stir in flours and baking powder to a thick batter.","Cook small pancakes in ghee 2 min per side."],
    ["wholeGrain","iron","fruit","calcium"],5,"Naturally sweet; add a few chocolate chips on the 9-year-old's.",True)
rec("bf-avocado-toast-egg","Avocado Toast with Boiled Egg","American",[B,S],[ST],5,10,4,2,
    [("Whole wheat bread",4,"count"),("Avocado",2,"count"),("Eggs",4,"count"),("Lemon",1,"count"),("Salt",2,"g"),("Tomato",1,"count","opt")],
    ["Boil eggs 9 min; cool and slice.","Mash avocado with lemon and salt.","Toast bread; spread avocado; top with egg and tomato."],
    ["wholeGrain","healthyFat","protein"],3,"Cut into 'soldiers' for the little one.")
rec("bf-veg-vermicelli-upma","Vermicelli Upma with Vegetables","Indian",[B,L],[ST],5,12,4,2,
    [("Vermicelli",200,"g"),("Carrot",1,"count"),("Peas",80,"g"),("Onion",1,"count"),("Mustard seeds",3,"g"),("Vegetable oil",15,"ml"),("Salt",3,"g"),("Lemon",1,"count")],
    ["Roast vermicelli dry 3 min; set aside.","Temper mustard seeds in oil; sauté onion, carrot, peas.","Add 400 ml water + salt; boil; add vermicelli; cover 4 min.","Finish with lemon."],
    ["grain","vegetable"],4,"Noodle-shaped breakfast — kids eat it with a fork happily.",True)
rec("bf-masala-oats","Savory Masala Oats","Indian",[B],[ST],5,10,4,2,
    [("Rolled oats",160,"g"),("Onion",1,"count"),("Tomato",1,"count"),("Peas",60,"g"),("Turmeric",1,"g"),("Cumin seeds",2,"g"),("Vegetable oil",10,"ml"),("Salt",3,"g")],
    ["Sizzle cumin in oil; sauté onion, tomato, peas 3 min.","Add oats + 500 ml water, turmeric, salt; simmer 5 min."],
    ["wholeGrain","fibre","vegetable"],3,"Top with a spoon of yogurt to cool it and soften flavours.")

# ---- lunches & dinners (30)
rec("dn-ip-khichdi","Instant Pot Vegetable Khichdi","Indian",[L,D],[IP],10,25,4,1,
    [("Basmati rice",200,"g"),("Moong dal",150,"g"),("Carrot",1,"count"),("Peas",80,"g"),("Potato",1,"count"),("Ghee",20,"g"),("Cumin seeds",3,"g"),("Turmeric",2,"g"),("Salt",4,"g"),("Plain yogurt",150,"g","opt")],
    ["Rinse rice + dal.","Sauté mode: ghee, cumin, then veg 2 min.","Add rice, dal, turmeric, salt, 1.2 l water.","Pressure cook 8 min, natural release 10 min. Serve with yogurt."],
    ["grain","protein","vegetable","iron"],5,"Soft, one-pot comfort food; add extra ghee on top for the kids.",True)
rec("dn-ip-dal-fry","Instant Pot Toor Dal Fry with Rice","Indian",[L,D],[IP],10,25,4,1,
    [("Toor dal",250,"g"),("Basmati rice",300,"g"),("Onion",1,"count"),("Tomato",2,"count"),("Garlic",3,"count"),("Ginger",5,"g"),("Cumin seeds",3,"g"),("Turmeric",2,"g"),("Ghee",20,"g"),("Salt",4,"g"),("Cilantro",1,"bunch","opt")],
    ["Sauté ghee, cumin, onion, ginger-garlic 3 min; add tomato 2 min.","Add rinsed dal, turmeric, salt, 900 ml water; pot-in-pot rice with 1:1.5 water on a trivet.","Pressure cook 10 min, natural release.","Whisk dal, top with cilantro."],
    ["protein","iron","grain","fibre"],5,"The classic — mild, yellow, spoonable. Mix with rice and a little ghee.",True)
rec("dn-ip-rajma","Instant Pot Rajma Chawal","Indian",[L,D],[IP],10,45,4,2,
    [("Rajma",250,"g"),("Basmati rice",300,"g"),("Onion",2,"count"),("Tomato",3,"count"),("Ginger",10,"g"),("Garlic",4,"count"),("Cumin seeds",3,"g"),("Coriander powder",5,"g"),("Garam masala",3,"g"),("Turmeric",2,"g"),("Vegetable oil",20,"ml"),("Salt",4,"g")],
    ["(Soak rajma 8 h or use quick-soak.)","Sauté onion, ginger, garlic in oil 5 min; add tomato + spices 3 min.","Add rajma + 750 ml water; pressure cook 30 min, natural release.","Mash a few beans to thicken; serve over rice."],
    ["protein","iron","fibre","grain"],5,"Kids' top request; keep chili out, add a squeeze of lemon.",True)
rec("dn-ip-chole","Instant Pot Chole (Mild Chickpea Curry)","Indian",[L,D],[IP],10,40,4,2,
    [("Chickpeas",250,"g"),("Onion",2,"count"),("Tomato",3,"count"),("Ginger",10,"g"),("Garlic",3,"count"),("Cumin seeds",3,"g"),("Coriander powder",5,"g"),("Garam masala",3,"g"),("Amchur",3,"g","opt"),("Vegetable oil",20,"ml"),("Salt",4,"g"),("Basmati rice",300,"g")],
    ["Soak chickpeas 8 h.","Sauté aromatics + spices; add tomato until jammy.","Add chickpeas + 700 ml water; pressure cook 35 min, natural release.","Serve with rice or whole wheat tortillas."],
    ["protein","iron","fibre"],4,"Serve with a yogurt swirl and cucumber slices.",True)
rec("dn-palak-paneer","Palak Paneer (Vitamix-smooth)","Indian",[D],[VM,ST],10,20,4,2,
    [("Spinach",3,"bunch"),("Paneer",250,"g"),("Onion",1,"count"),("Tomato",1,"count"),("Garlic",3,"count"),("Ginger",5,"g"),("Cumin seeds",3,"g"),("Garam masala",2,"g"),("Butter",15,"g"),("Salt",4,"g"),("Milk",50,"ml","opt")],
    ["Blanch spinach 2 min; blend smooth in Vitamix.","Sauté cumin, onion, ginger-garlic, tomato in butter.","Add spinach purée, salt, garam masala; simmer 5 min.","Fold in paneer cubes; splash of milk for creaminess."],
    ["iron","protein","calcium","vegetable"],4,"Green sauce hides the spinach; kids dunk roti or rice into it.")
rec("dn-matar-paneer","Matar Paneer","Indian",[L,D],[ST,IP],10,20,4,2,
    [("Paneer",250,"g"),("Peas",200,"g"),("Onion",1,"count"),("Tomato",3,"count"),("Ginger",5,"g"),("Garlic",2,"count"),("Cumin seeds",3,"g"),("Coriander powder",4,"g"),("Turmeric",2,"g"),("Garam masala",2,"g"),("Vegetable oil",15,"ml"),("Salt",4,"g"),("Kasuri methi",1,"g","opt")],
    ["Blend onion, tomato, ginger, garlic to a purée.","Fry cumin, add purée + spices; cook 8 min until oil separates.","Add peas, 200 ml water; simmer 5 min; add paneer 3 min."],
    ["protein","calcium","vegetable"],5,"Sweet peas + soft paneer = kid gold. Serve with roti or rice.",True)
rec("dn-aloo-gobi","Aloo Gobi (Potato & Cauliflower Stir-Fry)","Indian",[L,D],[ST],10,20,4,2,
    [("Potato",3,"count"),("Cauliflower",1,"count"),("Onion",1,"count"),("Ginger",5,"g"),("Cumin seeds",3,"g"),("Turmeric",2,"g"),("Coriander powder",4,"g"),("Vegetable oil",20,"ml"),("Salt",4,"g"),("Atta",300,"g")],
    ["Fry cumin; add onion, ginger 2 min.","Add potato, cauliflower, spices, salt; cover on low 15 min, stirring twice.","Make rotis from atta while it cooks."],
    ["vegetable","fibre","grain","wholeGrain"],4,"Roll it into a roti wrap for the 4-year-old.",True)
rec("dn-dal-palak","Instant Pot Dal Palak (Spinach Lentils)","Indian",[L,D],[IP],10,20,4,1,
    [("Moong dal",150,"g"),("Masoor dal",100,"g"),("Spinach",2,"bunch"),("Tomato",2,"count"),("Garlic",3,"count"),("Cumin seeds",3,"g"),("Turmeric",2,"g"),("Ghee",15,"g"),("Salt",4,"g"),("Basmati rice",300,"g")],
    ["Sauté cumin, garlic, tomato in ghee 3 min.","Add dals, turmeric, salt, 800 ml water; pressure cook 8 min.","Stir in chopped spinach on Sauté 2 min. Serve with rice."],
    ["protein","iron","vegetable","grain"],4,"Blend half with an immersion blender if kids dislike leaf bits.",True)
rec("dn-veg-pulao","Instant Pot Vegetable Pulao + Raita","Indian",[L,D],[IP],10,20,4,2,
    [("Basmati rice",300,"g"),("Frozen mixed vegetables",250,"g"),("Onion",1,"count"),("Cumin seeds",3,"g"),("Cinnamon",1,"g"),("Cardamom",1,"g"),("Ghee",20,"g"),("Salt",4,"g"),("Plain yogurt",250,"g"),("Cucumber",1,"count")],
    ["Sauté ghee, cumin, whole spices, onion 3 min.","Add veg, rinsed rice, salt, 450 ml water; pressure cook 5 min, natural release 5 min.","Grate cucumber into yogurt with salt for raita."],
    ["grain","vegetable","calcium"],5,"Fragrant and mild; serve with raita and papad.",True)
rec("dn-pav-bhaji","Pav Bhaji (Vegetable Mash with Buns)","Indian",[D],[IP,ST],15,25,4,2,
    [("Potato",3,"count"),("Cauliflower",0.5,"count"),("Peas",100,"g"),("Carrot",1,"count"),("Onion",2,"count"),("Tomato",3,"count"),("Bell pepper",1,"count"),("Pav bhaji masala",10,"g"),("Butter",40,"g"),("Salt",4,"g"),("Lemon",1,"count"),("Pav buns",8,"count")],
    ["Pressure cook potato, cauliflower, peas, carrot 5 min; mash.","Fry onion, pepper, tomato in butter; add masala; add mash + water; simmer 10 min.","Toast buns in butter; serve with lemon and onion."],
    ["vegetable","fibre","grain"],5,"Kids love the buttery buns; go light on masala for their portion.")
rec("dn-veg-sambar-rice","Instant Pot Sambar with Rice","Indian",[L,D],[IP],10,25,4,2,
    [("Toor dal",200,"g"),("Carrot",1,"count"),("Green beans",100,"g"),("Pumpkin",200,"g"),("Onion",1,"count"),("Tomato",1,"count"),("Sambar powder",10,"g"),("Tamarind paste",10,"g"),("Mustard seeds",3,"g"),("Curry leaves",1,"bunch","opt"),("Vegetable oil",15,"ml"),("Salt",4,"g"),("Basmati rice",300,"g")],
    ["Temper mustard seeds, curry leaves in oil; add onion, tomato.","Add dal, veg, sambar powder, tamarind, salt, 1 l water; pressure cook 10 min.","Whisk; serve with rice (pot-in-pot)."],
    ["protein","vegetable","fibre","grain"],3,"Serve mild and a little sweet (add a pinch of jaggery) for the kids.")
rec("dn-paneer-frankie","Paneer Frankie Wraps","Indian",[L,D],[ST],10,15,4,2,
    [("Paneer",250,"g"),("Whole wheat tortillas",4,"count"),("Onion",1,"count"),("Bell pepper",1,"count"),("Chaat masala",3,"g"),("Turmeric",1,"g"),("Vegetable oil",15,"ml"),("Salt",3,"g"),("Plain yogurt",100,"g"),("Cucumber",1,"count")],
    ["Stir-fry paneer strips, onion, pepper with turmeric, chaat masala, salt 5 min.","Warm tortillas; spread yogurt; fill; roll tight and wrap in foil."],
    ["protein","calcium","vegetable","wholeGrain"],5,"Roll-ups are a lunchbox winner; cut in half for small hands.",True)
rec("dn-ip-veg-biryani","Instant Pot Vegetable Biryani (Mild)","Indian",[D],[IP],15,25,4,3,
    [("Basmati rice",300,"g"),("Cauliflower",0.5,"count"),("Carrot",1,"count"),("Peas",100,"g"),("Potato",1,"count"),("Onion",2,"count"),("Plain yogurt",100,"g"),("Ginger",10,"g"),("Garlic",3,"count"),("Garam masala",3,"g"),("Turmeric",2,"g"),("Mint",1,"bunch","opt"),("Ghee",25,"g"),("Salt",4,"g")],
    ["Sauté onions in ghee until golden; add ginger-garlic, yogurt, spices.","Add veg, soaked rice, 400 ml water, mint; pressure cook 5 min, natural release 5 min.","Fluff and serve with raita."],
    ["grain","vegetable","calcium"],4,"Pick out whole spices before serving the kids.")
rec("dn-kadhi-chawal","Instant Pot Kadhi with Rice","Indian",[L,D],[IP],10,20,4,2,
    [("Plain yogurt",400,"g"),("Besan",60,"g"),("Turmeric",2,"g"),("Cumin seeds",3,"g"),("Mustard seeds",2,"g"),("Ginger",5,"g"),("Curry leaves",1,"bunch","opt"),("Ghee",15,"g"),("Salt",4,"g"),("Basmati rice",300,"g")],
    ["Whisk yogurt, besan, turmeric, salt with 700 ml water.","Temper cumin, mustard, ginger, curry leaves in ghee; add mixture.","Pressure cook 5 min; whisk. Serve with rice."],
    ["protein","calcium","grain"],4,"Tangy-creamy; kids mix it into rice like a soup.")
rec("dn-methi-thepla","Methi Thepla with Yogurt","Indian",[L,S],[ST],15,20,4,2,
    [("Atta",300,"g"),("Methi leaves",1,"bunch"),("Besan",30,"g"),("Turmeric",2,"g"),("Plain yogurt",200,"g"),("Vegetable oil",20,"ml"),("Salt",3,"g"),("Sesame seeds",5,"g","opt")],
    ["Knead atta, besan, chopped methi, turmeric, salt, 50 g yogurt and water into a soft dough.","Roll thin; cook on a hot pan with a little oil, 1 min per side.","Serve with yogurt."],
    ["wholeGrain","iron","calcium"],4,"Roll small ones; great cold in a lunchbox.",True)
rec("dn-veg-quesadilla","Black Bean & Cheese Quesadillas","Mexican",[L,D],[ST],10,10,4,1,
    [("Whole wheat tortillas",4,"count"),("Black beans",250,"g"),("Cheddar cheese",120,"g"),("Corn",100,"g"),("Bell pepper",1,"count"),("Taco seasoning",5,"g"),("Salsa",100,"g"),("Plain yogurt",100,"g","opt"),("Avocado",1,"count","opt")],
    ["Mash beans with taco seasoning; mix with corn and diced pepper.","Spread on half a tortilla, add cheese, fold.","Toast in a dry pan 3 min per side until crisp; cut into wedges.","Serve with salsa, yogurt, avocado."],
    ["protein","fibre","calcium","wholeGrain","vegetable"],5,"Triangles for dipping — reliably eaten by both kids.",True)
rec("dn-veg-tacos","Build-Your-Own Veggie Tacos","Mexican",[D],[ST],15,15,4,2,
    [("Corn tortillas",8,"count"),("Pinto beans",250,"g"),("Sweet potato",2,"count"),("Corn",100,"g"),("Lettuce",1,"bunch"),("Tomato",2,"count"),("Cheddar cheese",80,"g"),("Taco seasoning",5,"g"),("Olive oil",15,"ml"),("Lime",1,"count"),("Sour cream",100,"g","opt")],
    ["Roast diced sweet potato with oil + seasoning 15 min (oven or air fryer).","Warm beans and corn.","Set out warm tortillas and bowls of everything; everyone builds their own."],
    ["protein","fibre","vitaminA","vegetable"],5,"Choice = buy-in. Let kids assemble; keep toppings mild.")
rec("dn-burrito-bowl","Burrito Bowls with Cilantro-Lime Rice","Mexican",[L,D],[IP],10,20,4,2,
    [("Brown rice",300,"g"),("Black beans",250,"g"),("Corn",150,"g"),("Tomato",2,"count"),("Avocado",1,"count"),("Cheddar cheese",80,"g"),("Cilantro",1,"bunch"),("Lime",1,"count"),("Salsa",100,"g"),("Salt",3,"g")],
    ["Pressure cook brown rice (1:1.25 water) 22 min.","Stir lime, cilantro, salt into rice.","Layer rice, beans, corn, tomato, avocado, cheese, salsa."],
    ["wholeGrain","protein","fibre","healthyFat"],4,"Serve components separately for the 4-year-old.",True)
rec("dn-pasta-hidden-veg","Pasta with Hidden-Veggie Tomato Sauce","Italian",[L,D],[VM,ST],10,20,4,1,
    [("Whole wheat pasta",350,"g"),("Marinara sauce",400,"g"),("Carrot",2,"count"),("Zucchini",1,"count"),("Red chili powder",0,"g","opt"),("Garlic",2,"count"),("Olive oil",15,"ml"),("Parmesan",40,"g"),("Italian seasoning",2,"g"),("Salt",3,"g")],
    ["Steam carrot + zucchini 8 min; blend with marinara in Vitamix until smooth.","Sauté garlic in oil; add sauce, seasoning; simmer 5 min.","Toss with cooked pasta; top with parmesan."],
    ["wholeGrain","vegetable","vitaminA"],5,"Sauce is smooth and orange-red; kids never spot the vegetables.",True)
rec("dn-mac-cheese-cauli","Cauliflower Mac & Cheese","American",[D],[VM,ST],10,20,4,1,
    [("Pasta",350,"g"),("Cauliflower",0.5,"count"),("Milk",300,"ml"),("Cheddar cheese",150,"g"),("Butter",20,"g"),("All-purpose flour",20,"g"),("Salt",3,"g"),("Peas",100,"g","opt")],
    ["Boil pasta; steam cauliflower florets until soft.","Blend cauliflower with milk in Vitamix.","Make roux with butter + flour; whisk in cauliflower-milk; melt in cheese.","Toss with pasta and peas."],
    ["calcium","protein","vegetable"],5,"The 4-year-old's favourite; half the sauce is cauliflower.")
rec("dn-veg-pizza","Homemade Veggie Pizza","Italian",[D],[OV],15,15,4,2,
    [("Pizza dough",500,"g"),("Marinara sauce",200,"g"),("Mozzarella",200,"g"),("Bell pepper",1,"count"),("Corn",80,"g"),("Mushrooms",100,"g","opt"),("Spinach",1,"bunch","opt"),("Olive oil",10,"ml"),("Italian seasoning",2,"g")],
    ["Preheat oven to 245 °C.","Stretch dough; spread sauce; kids add cheese and toppings.","Bake 12–14 min until bubbling."],
    ["calcium","vegetable","grain"],5,"Friday pizza night; each kid decorates their own half.")
rec("dn-veg-fried-rice","Vegetable Egg Fried Rice","Chinese-style",[L,D],[ST],10,12,4,2,
    [("Basmati rice",300,"g","","cooked and cooled"),("Eggs",3,"count"),("Frozen mixed vegetables",250,"g"),("Garlic",2,"count"),("Soy sauce",20,"ml"),("Sesame oil",5,"ml"),("Vegetable oil",15,"ml"),("Salt",2,"g")],
    ["Scramble eggs in a hot wok; set aside.","Stir-fry garlic, veg 3 min; add rice, soy sauce; toss 3 min.","Return eggs; finish with sesame oil."],
    ["grain","protein","vegetable"],5,"Great use of leftover rice; skip egg for an egg-free version (add tofu).",True)
rec("dn-tofu-stirfry-noodles","Tofu & Broccoli Noodle Stir-Fry","Chinese-style",[D],[ST],10,15,4,2,
    [("Rice noodles",250,"g"),("Firm tofu",400,"g"),("Broccoli",1,"count"),("Carrot",1,"count"),("Garlic",2,"count"),("Ginger",5,"g"),("Soy sauce",30,"ml"),("Honey",10,"g"),("Cornstarch",10,"g"),("Vegetable oil",20,"ml")],
    ["Toss pressed tofu cubes in cornstarch; pan-fry until golden.","Stir-fry broccoli, carrot, garlic, ginger 4 min.","Add soaked noodles, soy-honey sauce, tofu; toss 2 min."],
    ["protein","calcium","vegetable","iron"],4,"Crispy tofu cubes eaten as finger food; cut broccoli into 'little trees'.")
rec("dn-lentil-soup-bread","Instant Pot Red Lentil Soup with Garlic Bread","Mediterranean",[L,D],[IP,OV],10,20,4,1,
    [("Masoor dal",250,"g"),("Carrot",2,"count"),("Celery",2,"count"),("Onion",1,"count"),("Garlic",3,"count"),("Ground cumin",3,"g"),("Vegetable stock",1000,"ml"),("Olive oil",20,"ml"),("Lemon",1,"count"),("Whole wheat bread",4,"count"),("Butter",20,"g"),("Salt",3,"g")],
    ["Sauté onion, carrot, celery, garlic in oil 4 min.","Add lentils, cumin, stock; pressure cook 8 min.","Blend partly for creaminess; lemon to taste.","Butter + garlic on bread; toast."],
    ["protein","iron","fibre","vegetable"],4,"Smooth soup + bread for dunking; sneaks in celery and carrot.",True)
rec("dn-veg-chow-mein","Veggie Hakka Noodles","Chinese-style",[L,D],[ST],10,15,4,2,
    [("Whole wheat pasta",300,"g","","or hakka noodles"),("Cabbage",0.25,"count"),("Carrot",1,"count"),("Bell pepper",1,"count"),("Garlic",3,"count"),("Soy sauce",25,"ml"),("Vinegar",10,"ml"),("Vegetable oil",20,"ml"),("Black pepper",1,"g"),("Salt",2,"g")],
    ["Boil noodles; drain and toss in a little oil.","Stir-fry garlic and julienned veg on high 3 min.","Add noodles, soy, vinegar, pepper; toss 2 min."],
    ["grain","vegetable"],5,"Noodles + crunchy veg; keep the sauce mild.",True)
rec("dn-sheet-pan-veg-paneer","Sheet-Pan Paneer Tikka & Veggies","Indian",[D],[OV,AF],15,20,4,2,
    [("Paneer",300,"g"),("Bell pepper",2,"count"),("Onion",1,"count"),("Broccoli",1,"count"),("Plain yogurt",150,"g"),("Turmeric",2,"g"),("Coriander powder",4,"g"),("Garam masala",2,"g"),("Lemon",1,"count"),("Vegetable oil",15,"ml"),("Salt",3,"g"),("Naan",4,"count","opt")],
    ["Marinate paneer + veg in yogurt, spices, lemon, oil, salt 15 min.","Roast at 220 °C for 18–20 min (or air fry 12 min at 200 °C).","Serve with naan."],
    ["protein","calcium","vegetable"],4,"Skewer-free 'tikka' cubes; kids eat with fingers.")
rec("dn-dahi-aloo","Dahi Aloo (Potatoes in Yogurt Gravy)","Indian",[L,D],[ST],10,15,4,1,
    [("Potato",4,"count"),("Plain yogurt",250,"g"),("Cumin seeds",3,"g"),("Turmeric",2,"g"),("Coriander powder",4,"g"),("Ginger",5,"g"),("Ghee",15,"g"),("Salt",3,"g"),("Atta",300,"g")],
    ["Boil and cube potatoes.","Temper cumin, ginger in ghee; add spices, whisked yogurt on low; stir 3 min.","Add potatoes, 150 ml water; simmer 5 min. Serve with rotis."],
    ["calcium","protein","grain","wholeGrain"],4,"Mild, soft, tangy — easy for the 4-year-old.")
rec("dn-quinoa-veg-pulao","Instant Pot Quinoa Vegetable Pulao","Indian",[L,D],[IP],10,15,4,2,
    [("Quinoa",300,"g"),("Frozen mixed vegetables",250,"g"),("Onion",1,"count"),("Cumin seeds",3,"g"),("Turmeric",1,"g"),("Ghee",15,"g"),("Salt",4,"g"),("Lemon",1,"count"),("Plain yogurt",200,"g")],
    ["Sauté cumin, onion in ghee; add veg 2 min.","Add rinsed quinoa, turmeric, salt, 450 ml water; pressure cook 1 min, natural release 10 min.","Fluff with lemon; serve with yogurt."],
    ["wholeGrain","protein","vegetable"],3,"Looks like rice; a little ghee helps acceptance.",True)
rec("dn-veggie-burgers","Sweet Potato & Black Bean Burgers","American",[D],[OV],15,20,4,2,
    [("Sweet potato",2,"count"),("Black beans",250,"g"),("Rolled oats",80,"g"),("Onion",0.5,"count"),("Ground cumin",3,"g"),("Salt",3,"g"),("Pav buns",4,"count"),("Lettuce",1,"bunch"),("Tomato",1,"count"),("Cheddar cheese",60,"g","opt")],
    ["Microwave sweet potato until soft; mash with beans, oats, onion, cumin, salt.","Shape patties; bake 200 °C 20 min, flipping once.","Serve in buns with lettuce, tomato, cheese."],
    ["protein","fibre","vitaminA","wholeGrain"],4,"Burger night — kids can hold it; make mini sliders.")
rec("dn-egg-curry","Instant Pot Egg Curry with Rice","Indian",[D],[IP],10,20,4,3,
    [("Eggs",6,"count"),("Onion",2,"count"),("Tomato",3,"count"),("Ginger",5,"g"),("Garlic",3,"count"),("Coriander powder",5,"g"),("Turmeric",2,"g"),("Garam masala",2,"g"),("Vegetable oil",20,"ml"),("Salt",4,"g"),("Basmati rice",300,"g")],
    ["Pressure cook eggs 5 min; peel.","Sauté onion, ginger-garlic, tomato, spices 8 min; add 300 ml water; simmer 5 min.","Add halved eggs; serve with rice."],
    ["protein","grain"],3,"Serve eggs halved with gravy on the side for the little one.")
rec("dn-veg-korma","Mild Vegetable Korma","Indian",[D],[ST,VM],15,25,4,2,
    [("Cauliflower",0.5,"count"),("Carrot",2,"count"),("Green beans",100,"g"),("Peas",100,"g"),("Potato",1,"count"),("Onion",1,"count"),("Cashews",40,"g"),("Coconut milk",200,"ml"),("Ginger",5,"g"),("Garlic",2,"count"),("Coriander powder",4,"g"),("Garam masala",2,"g"),("Vegetable oil",15,"ml"),("Salt",4,"g"),("Naan",4,"count","opt")],
    ["Blend cashews, onion, ginger, garlic with 100 ml water in Vitamix.","Fry paste in oil 5 min; add spices, coconut milk, veg, salt, 200 ml water.","Simmer covered 15 min. Serve with naan or rice."],
    ["vegetable","healthyFat","fibre"],4,"Creamy and sweet; a good 'introduce a vegetable' dish.")

# ---- snacks & smoothies (8)
rec("sn-spinach-smoothie","Green Monster Smoothie","American",[S,B],[VM],5,0,2,1,
    [("Spinach",1,"bunch"),("Banana",1,"count"),("Frozen mango chunks",150,"g"),("Plain yogurt",150,"g"),("Milk",200,"ml"),("Chia seeds",10,"g","opt")],
    ["Add everything to Vitamix, liquids first.","Blend on high 45 s until silky."],
    ["fruit","iron","calcium","vegetable"],5,"Bright green and sweet — call it 'monster juice'; spinach is undetectable.")
rec("sn-berry-smoothie","Berry Oat Smoothie","American",[S,B],[VM],5,0,2,1,
    [("Frozen mixed berries",150,"g"),("Banana",1,"count"),("Rolled oats",30,"g"),("Greek yogurt",150,"g"),("Milk",200,"ml"),("Honey",10,"g","opt")],
    ["Blend everything 45 s on high."],
    ["fruit","wholeGrain","protein","calcium"],5,"Purple = popular. Freeze extra into popsicles.")
rec("sn-mango-lassi","Mango Lassi","Indian",[S],[VM],5,0,2,1,
    [("Mango",1,"count"),("Plain yogurt",250,"g"),("Milk",100,"ml"),("Cardamom",0.5,"g","opt"),("Honey",10,"g","opt")],
    ["Blend mango, yogurt, milk, cardamom until smooth."],
    ["fruit","calcium","protein"],5,"Use frozen mango chunks off-season.")
rec("sn-carrot-beet-smoothie","Carrot Beet Orange Smoothie","American",[S],[VM],5,0,2,2,
    [("Carrot",1,"count"),("Beetroot",0.5,"count"),("Orange",2,"count"),("Apple",1,"count"),("Ginger",2,"g","opt")],
    ["Blend with 200 ml water on high 60 s (Vitamix handles raw carrot and beet)."],
    ["fruit","vegetable","vitaminA","vitaminC"],3,"Hot-pink colour sells it; add more orange if too earthy.")
rec("sn-roasted-makhana","Ghee-Roasted Makhana","Indian",[S],[ST],2,8,4,2,
    [("Makhana",100,"g"),("Ghee",15,"g"),("Salt",2,"g"),("Turmeric",1,"g","opt"),("Black pepper",1,"g","opt")],
    ["Roast makhana in ghee on low 6–8 min until crisp.","Toss with salt and turmeric."],
    ["protein"],4,"Crunchy like popcorn; stores a week in a jar.",True)
rec("sn-fruit-chaat","Rainbow Fruit Chaat","Indian",[S],[],10,0,4,1,
    [("Apple",1,"count"),("Banana",1,"count"),("Orange",1,"count"),("Grapes",100,"g"),("Pomegranate",0.5,"count"),("Chaat masala",1,"g","opt"),("Lemon",0.5,"count")],
    ["Chop fruit into bite-size pieces.","Toss with lemon; chaat masala for the grown-ups' portion."],
    ["fruit","vitaminC","fibre"],5,"Toothpick 'kebabs' make it a game.",True)
rec("sn-veg-sticks-hummus","Veggie Sticks with Hummus","Mediterranean",[S,L],[VM],10,0,4,1,
    [("Chickpeas",250,"g","","canned or cooked"),("Sesame seeds",20,"g"),("Lemon",1,"count"),("Garlic",1,"count"),("Olive oil",30,"ml"),("Salt",2,"g"),("Carrot",2,"count"),("Cucumber",1,"count"),("Bell pepper",1,"count"),("Pita bread",2,"count","opt")],
    ["Blend chickpeas, sesame, lemon, garlic, oil, salt + 50 ml water in Vitamix until creamy.","Cut veg into sticks; serve with hummus and pita triangles."],
    ["protein","fibre","vegetable","healthyFat"],4,"Dipping is the hook; start with cucumber and carrot.",True)
rec("sn-oat-banana-cookies","3-Ingredient Oat Banana Cookies","American",[S],[OV],5,15,4,1,
    [("Banana",2,"count"),("Rolled oats",150,"g"),("Dark chocolate chips",30,"g","opt"),("Cinnamon",1,"g","opt"),("Raisins",30,"g","opt")],
    ["Mash bananas; stir in oats, chocolate chips or raisins.","Drop spoonfuls on a tray; bake 180 °C 12–15 min."],
    ["wholeGrain","fruit","fibre"],5,"Kids can mix and scoop; no added sugar.",True)

assert len(R) >= 50, len(R)
ids = [r["seedID"] for r in R]; assert len(ids) == len(set(ids))
os.makedirs("seed", exist_ok=True)
json.dump(dict(version=1, ingredients=I), open("seed/ingredients.json","w"), indent=1, ensure_ascii=False)
json.dump(dict(version=1, recipes=R), open("seed/recipes.json","w"), indent=1, ensure_ascii=False)
bf = sum(B in r["mealTypes"] for r in R); ld = sum((L in r["mealTypes"]) or (D in r["mealTypes"]) for r in R)
ip = sum(IP in r["appliances"] for r in R); vm = sum(VM in r["appliances"] for r in R); q = sum(r["isQuick"] for r in R)
egg = sum(r["containsEgg"] for r in R)
print(f"ingredients={len(I)} recipes={len(R)} breakfast={bf} lunch/dinner={ld} instantPot={ip} vitamix={vm} quick={q} egg={egg}")
