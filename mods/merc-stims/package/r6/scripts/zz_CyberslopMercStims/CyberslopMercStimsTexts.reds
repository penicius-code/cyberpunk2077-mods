// Cyberslop Merc Stims 1.2.0 - all texts (Codeware localization). Durations are game hours.
module CyberslopMercStims

import Codeware.Localization.*

public class CyberslopMercStimsTexts extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // ---------------------------------------------------------------- stims (1.0.0)
    this.Text("CyberslopStims-Vigil-Name", "Vigil Wakefulness Agent");
    this.Text("CyberslopStims-Vigil-Desc", "Biotechnica eugeroic, the modafinil line taken to its corporate end. No rush, no high, no shaking hands: the brain simply stops asking for sleep. Corpo night shifts, netrunner marathons and long-range overwatch teams live on it.\n\nHolds your Energy up for 12 hours (it cannot drop below the level after the dose) and adds 15 Energy at once. Slightly sharper: faster reloads and aiming.\n\nThe tiredness is postponed, not erased: when it wears off, a quarter of the fatigue it held back hits at once. Sleep pays it back. Every extra dose in a row works less and makes that bill bigger.");
    this.Text("CyberslopStims-HoldFast-Name", "Hold Fast Alertness Autoinjector");
    this.Text("CyberslopStims-HoldFast-Desc", "Militech field-issue go-pill in a spring autoinjector: pharmaceutical dextroamphetamine, the same chemistry pilots and recon teams have flown on for a century. Clean, measured, no euphoria at field dose. Usable in combat.\n\nHolds your Energy up for 6 hours and adds 25 Energy at once. Better endurance while it runs: +15% stamina regeneration, +15 stamina, slightly faster reloads.\n\nWhen it wears off, half of the fatigue it held back lands at once. Every extra dose in a row works less and makes that crash bigger.");
    this.Text("CyberslopStims-Surge-Name", "Surge Wake-Up Tabs");
    this.Text("CyberslopStims-Surge-Desc", "The street's oldest stay-awake: ephedrine, caffeine and a cheap synthetic stimulant pressed into green tabs. Sold over the counter in half the city, under it in the other half.\n\nHolds your Energy up for 4 hours and adds 20 Energy at once. Gets you through a shift, not a firefight: shaky hands while it runs (weapon recoil 8% worse), a little extra stamina regeneration.\n\nNothing is free on Surge: when it wears off, every point of fatigue it held back hits at once.");
    this.Text("CyberslopStims-Kagami-Name", "Kagami Reflex Tuner");
    this.Text("CyberslopStims-Kagami-Desc", "Arasaka Special Operations combat neurostim. A synaptic accelerator and a beta-blocker in one injection: the world slows down a hair, the heart rate stays flat, the hands go still. No euphoria, nothing to enjoy, just a merc running at full spec. Usable in combat.\n\nFor 1.5 hours: 25% less recoil, 20% faster reloads, 25% faster aiming, +10% chance to shrug off part of a hit (mitigation), +10% stamina regeneration, and 20 temporary Energy.\n\nAfterwards the nerves pay for it: the temporary Energy goes, Nerve -10 and an hour of Neural Lag. A second dose while it still runs buys nothing but a fried nervous system.");
    this.Text("CyberslopStims-Crank-Name", "Crank");
    this.Text("CyberslopStims-Crank-Desc", "Bathtub methamphetamine from Pacifica cook shacks, smoked from a cracked glass bulb. Cheap, filthy and very strong: hours of jittery, euphoric wakefulness that has kept more than one gonk on their feet through a three-day job, and then put them in the ground.\n\nA Dark Future narcotic: Overdrive stacks with more temporary Energy than any pill, Euphoria, addiction and overdose risk included.");

    // ---------------------------------------------------------------- nerve and sleep
    this.Text("CyberslopStims-Steady-Name", "Steady Beta-Blocker");
    this.Text("CyberslopStims-Steady-Desc", "Militech marksman's propranolol, the same molecule surgeons, concert pianists and snipers have taken for a century. It does nothing for the mind and everything for the body that betrays it: no pounding heart, no tremor, no sweat for a guard's thermal optics to pick up. Usable in combat.\n\nFor 4 hours your Nerve cannot fall below its level at the dose. Steadier hands (10% less recoil), slightly faster aiming, harder to spot.\n\nA heart held at sixty beats cannot sprint like a racing one: -10% stamina regeneration while it runs.");
    this.Text("CyberslopStims-Serene-Name", "Serene Anxiolytic");
    this.Text("CyberslopStims-Serene-Desc", "Biotechnica's non-sedating anxiolytic for executives who cannot afford a bad day. It quiets the background hum of dread without fogging the head or touching the reward system: no high, no dependence, no hangover.\n\nRestores 30 Nerve gradually over 1 hour. Slightly steadier hands while it works.\n\nPrescription-only in theory; every medic in the city stocks it anyway.");
    this.Text("CyberslopStims-ZeroPoint-Name", "Zero Point Calm Injector");
    this.Text("CyberslopStims-ZeroPoint-Desc", "Arasaka executive-protection pharmacology: a fast-acting receptor modulator that flattens panic in seconds. Bodyguards carry it for principals under fire and keep the last one for themselves. Usable in combat.\n\n+25 Nerve at once. For 20 minutes afterwards you are calm and slightly slowed: steadier hands, a little slower to aim and recover.\n\nNot euphoric, not addictive. Just very, very calm.");
    this.Text("CyberslopStims-Lull-Name", "Lull Sleep Aid");
    this.Text("CyberslopStims-Lull-Desc", "Biotechnica zolpidem-class hypnotic. Take it, lie down, and the night does what it is supposed to: deep, uninterrupted sleep, the kind stims steal from you.\n\nSleep within 1 hour of the dose and that sleep restores 30% more Energy and pays back stim sleep debt half as fast again. Works for 4 hours after the dose.\n\nFight it and it fights back: stay up past the first hour and you are drowsy for the rest of the window (slower aim, shaky hands, heavy limbs).");

    // ---------------------------------------------------------------- netrunning, detox, combat
    this.Text("CyberslopStims-Boost-Name", "Boost Neurostim");
    this.Text("CyberslopStims-Boost-Desc", "Zetatech's licensed take on the old street drug Boost: a nootropic cocktail that drives the prefrontal cortex and the deck interface at the same time. Netrunners call it a second processor. Usable in combat.\n\nFor 2 hours: 25% faster RAM recovery and 20% faster quickhack uploads.\n\nThe brain bills it afterwards: a 1-hour migraine with slower RAM recovery and slower aiming.");
    this.Text("CyberslopStims-Rapidetox-Name", "Rapidetox Inhaler");
    this.Text("CyberslopStims-Rapidetox-Desc", "The classic street-doc purge: enzymes and chelators that strip alcohol and narcotics out of the blood in under a minute. Mercs keep one in the glovebox for the call that comes in at the wrong time.\n\nEnds every active alcohol and narcotic effect at once, along with any Energy they were lending you. Does nothing for an addiction.\n\nYour body notices: Hydration -15 and half an hour of nausea.");
    this.Text("CyberslopStims-Antitox-Name", "Antitox Pretreatment");
    this.Text("CyberslopStims-Antitox-Desc", "Militech nerve-agent pretreatment, the pyridostigmine protocol taken before a unit goes into contaminated ground. Take it before the fight, not after.\n\nFor 1 hour: immune to poison, +50 chemical resistance. Usable in combat.\n\nWhen it clears, mild nausea for half an hour and a little thirst. ChelaTox cures a poisoning; this stops it happening.");
    this.Text("CyberslopStims-Hardline-Name", "Hardline Trauma Injector");
    this.Text("CyberslopStims-Hardline-Desc", "Arasaka trauma-response shot: synthetic adrenaline, a dissociative and a fast glucose load. It is what keeps a bodyguard on their feet after a round to the vest. Usable in combat.\n\nFor 10 minutes: you cannot be knocked down or stunned, +25% stamina regeneration.\n\nThen the crash: Nerve -15 and half an hour of shaking exhaustion with less stamina.");
    this.Text("CyberslopStims-Ghostline-Name", "Ghostline Signal Scrubber");
    this.Text("CyberslopStims-Ghostline-Desc", "A disposable black-ICE chip from the fixer circuit. Slot it and it spends the next 12 hours scrubbing you out of the city's chatter: your agent's location pings, your optics' handshake, your car's transponder and every gang scanner fishing for them get fed noise and dead ends. The chip cooks itself when it is done.\n\nFor 12 hours nobody can track you down while you sleep in a vehicle: no gang ambush wakes you. A professional does not get found napping.");
    this.Text("CyberslopStims-Emberline-Name", "Emberline Nicotinic Primer");
    this.Text("CyberslopStims-Emberline-Desc", "Biotechnica's answer to the oldest habit in the city. A receptor primer that turns nicotine from a craving into a tool: the jitters, the withdrawal and the smoker's crash are switched off, and what is left is the focus. Old-school snipers swear by it.\n\nFor 24 hours: nicotine withdrawal is suppressed (the addiction itself stays), smoking leaves no debuff behind, and while a cigarette is burning you are sharp: 20% less recoil, 20% faster aiming, 10% faster reloads, and half of any Nerve loss is restored.\n\nWithout a smoke it does nothing for you. Expensive, and worth every eddie to a smoker.");

    // ---------------------------------------------------------------- oxygen
    this.Text("CyberslopStims-Respirocyte-Name", "Respirocyte Infusion");
    this.Text("CyberslopStims-Respirocyte-Desc", "Biotechnica medical nanotech: billions of artificial red cells, diamondoid pressure vessels that carry two hundred times the oxygen of blood. Built for free divers and Trauma Team, sold to anyone with the money. Usable in combat.\n\nFor 6 hours: 30% more oxygen reserve and 30% faster oxygen recovery (Cyberslop Endurance), +5 stamina.");
    this.Text("CyberslopStims-Bronchodilator-Name", "Bronchodilator Inhaler");
    this.Text("CyberslopStims-Bronchodilator-Desc", "Plain salbutamol in a pocket inhaler. Opens the airways in a minute; asthmatics, smog-lung kids and sprinters have used it for a century. Usable in combat.\n\nFor 1 hour: 30% faster oxygen recovery (Cyberslop Endurance). Slightly shaky hands.");

    // ---------------------------------------------------------------- street
    this.Text("CyberslopStims-Synthcoke-Name", "Synthcoke");
    this.Text("CyberslopStims-Synthcoke-Desc", "Lab-pure synthetic cocaine, the corpo party drug since the 2020s: cut into lines on a mirror in a Night City penthouse, gone up a nose in a club toilet. A bright, short, confident high.\n\nA Dark Future narcotic: 2-3 Overdrive stacks of temporary Energy, Euphoria, addiction and overdose risk included. Sits between Vanitol and Crank.");

    // ---------------------------------------------------------------- performance food and drink
    this.Text("CyberslopStims-ProteoMax-Name", "ProteoMax Performance Meal");
    this.Text("CyberslopStims-ProteoMax-Desc", "Biotechnica bio-printed real-muscle protein, complex carbs and micronutrients, sealed hot. A meal built by sports scientists, not a vending machine. No junk, no bio-corruption.\n\nA full meal for Dark Future. For 6 hours: +10 stamina and 10% faster health regeneration.");
    this.Text("CyberslopStims-Electra-Name", "Electra Isotonic");
    this.Text("CyberslopStims-Electra-Desc", "Zetatech isotonic: sodium, potassium and magnesium at blood concentration, the way real sports drinks were meant to be before the sugar water took over.\n\nLarge Hydration for Dark Future. For 3 hours: +10% stamina regeneration.");
    this.Text("CyberslopStims-CorpoDaily-Name", "Corpo Daily Multivitamin");
    this.Text("CyberslopStims-CorpoDaily-Desc", "Biotechnica's daily stack for people who live on vending machines and adrenaline: vitamins, minerals, omega-3 and gut flora in one capsule.\n\nFor 24 hours: Hydration and Nutrition drain 15% slower, +5% health regeneration.");
    this.Text("CyberslopStims-Ketone-Name", "Ketone Ester Shot");
    this.Text("CyberslopStims-Ketone-Desc", "Militech endurance fuel: a ketone ester shot that feeds muscle and brain directly, the same stuff pro cyclists and special forces have drunk since the 2010s. Tastes like jet fuel. Usable in combat.\n\nSmall Nutrition for Dark Future. For 2 hours: +15% stamina regeneration, +5 stamina. No sugar crash.");
    this.Text("CyberslopStims-ColdBrew-Name", "Arasaka Executive Cold Brew");
    this.Text("CyberslopStims-ColdBrew-Desc", "Real Kyushu-grown coffee cold-brewed with L-theanine, poured in Arasaka Tower's executive lounge and sold to everyone else at a markup. Caffeine without the jitters.\n\nCaffeine and a little Hydration for Dark Future. For 2 hours: slightly faster aiming.");
    this.Text("CyberslopStims-HydraSalt-Name", "Militech HydraSalt Canteen");
    this.Text("CyberslopStims-HydraSalt-Desc", "Military oral rehydration salts pre-mixed in a field canteen. Drink it on the move, even under fire.\n\nMedium Hydration for Dark Future, usable in combat.");
    this.Text("CyberslopStims-NutriGel-Name", "Militech NutriGel Pouch");
    this.Text("CyberslopStims-NutriGel-Desc", "Ration paste in a tear-open pouch: calories, protein and salt, nothing else. Tastes of nothing at all.\n\nMedium Nutrition for Dark Future, usable in combat.");

    // ---------------------------------------------------------------- chrome maintenance
    this.Text("CyberslopStims-NeuroSync-Name", "NeuroSync Myelin Supplement");
    this.Text("CyberslopStims-NeuroSync-Desc", "Kang Tao maintenance dose for reflex chrome. Sandevistans and Kerenzikovs push signals faster than the nerves were built for; NeuroSync feeds the myelin sheaths that insulate them.\n\nFor 12 hours: Sandevistan recharge and Kerenzikov cooldown 10% shorter, slightly faster aiming.");
    this.Text("CyberslopStims-OsteoCal-Name", "OsteoCal Bone-Lacing Supplement");
    this.Text("CyberslopStims-OsteoCal-Desc", "Calcium, vitamin D3 and K2 dosed for bone lacing and chrome anchor points. Laced bones carry more load; the living bone around the anchors has to keep up.\n\nFor 24 hours: +25 carry capacity, +10 melee resistance.");
    this.Text("CyberslopStims-BioCoolant-Name", "BioCoolant Electrolyte Gel");
    this.Text("CyberslopStims-BioCoolant-Desc", "Militech implant-support gel: electrolytes and a thermal buffer for bodies that run heavy chrome on their own bioelectric power. Keeps the deck and the subdermal heat sinks inside their limits.\n\nFor 6 hours: 10% faster RAM recovery, +20 thermal resistance.");
    this.Text("CyberslopStims-Rejectol-Name", "Rejectol Maintenance Dose");
    this.Text("CyberslopStims-Rejectol-Desc", "The daily low-dose immunosuppressant every heavily chromed body lives on. Not the emergency shot: the boring maintenance that keeps the immune system from waging war on your implants.\n\nFor 24 hours: 15% less humanity damage from chrome and violence (Wannabe Edgerunner). The immune system is turned down for everything else too: -5% health regeneration.");

    // ---------------------------------------------------------------- status effects
    this.Text("CyberslopStims-Vigil_Active-Name", "Vigil");
    this.Text("CyberslopStims-Vigil_Active-Desc", "Wakefulness agent. Energy cannot drop below its level after the dose. Faster reloads and aiming. Sleep debt when it ends.");
    this.Text("CyberslopStims-HoldFast_Active-Name", "Hold Fast");
    this.Text("CyberslopStims-HoldFast_Active-Desc", "Military go-pill. Energy held up. +15% stamina regeneration, +15 stamina, faster reloads. Sleep debt when it ends.");
    this.Text("CyberslopStims-Surge_Active-Name", "Surge");
    this.Text("CyberslopStims-Surge_Active-Desc", "Wired on wake-up tabs. Energy held up, shaky hands (more recoil). All the held-back fatigue lands when it ends.");
    this.Text("CyberslopStims-Kagami_Active-Name", "Kagami Reflex Tuning");
    this.Text("CyberslopStims-Kagami_Active-Desc", "Combat neurostim. 25% less recoil, 20% faster reloads, 25% faster aiming, +10% mitigation chance.");
    this.Text("CyberslopStims-Kagami_Lag-Name", "Neural Lag");
    this.Text("CyberslopStims-Kagami_Lag-Desc", "The synapses are catching up after Kagami. Slower reloads and aiming, more recoil, -5% mitigation chance, slower stamina recovery.");
    this.Text("CyberslopStims-Steady_Active-Name", "Steady");
    this.Text("CyberslopStims-Steady_Active-Desc", "Beta-blocked. Nerve cannot fall below its level at the dose. Steadier aim, harder to spot, -10% stamina regeneration.");
    this.Text("CyberslopStims-Lull_Drowsy-Name", "Drowsy");
    this.Text("CyberslopStims-Lull_Drowsy-Desc", "A sleep aid with no bed. Slower aim, shaky hands, heavy limbs. Lie down.");
    this.Text("CyberslopStims-Boost_Active-Name", "Boost");
    this.Text("CyberslopStims-Boost_Active-Desc", "Neurostim. 25% faster RAM recovery, 20% faster quickhack uploads.");
    this.Text("CyberslopStims-Boost_Migraine-Name", "Boost Migraine");
    this.Text("CyberslopStims-Boost_Migraine-Desc", "The comedown. Slower RAM recovery and aiming.");
    this.Text("CyberslopStims-Antitox_Active-Name", "Antitox");
    this.Text("CyberslopStims-Antitox_Active-Desc", "Pretreated. Immune to poison, +50 chemical resistance.");
    this.Text("CyberslopStims-Antitox_Nausea-Name", "Antitox Nausea");
    this.Text("CyberslopStims-Antitox_Nausea-Desc", "The pretreatment clearing out. Slightly slower stamina recovery.");
    this.Text("CyberslopStims-Hardline_Active-Name", "Hardline");
    this.Text("CyberslopStims-Hardline_Active-Desc", "Trauma shot. Cannot be knocked down or stunned, +25% stamina regeneration.");
    this.Text("CyberslopStims-Hardline_Crash-Name", "Adrenal Crash");
    this.Text("CyberslopStims-Hardline_Crash-Desc", "The adrenaline is gone. Shaking, less stamina, much slower recovery.");
    this.Text("CyberslopStims-ProteoMax_Active-Name", "Well Fuelled");
    this.Text("CyberslopStims-ProteoMax_Active-Desc", "A proper performance meal. +10 stamina, faster health regeneration.");
    this.Text("CyberslopStims-Electra_Active-Name", "Electrolytes");
    this.Text("CyberslopStims-Electra_Active-Desc", "Balanced electrolytes. +10% stamina regeneration.");
    this.Text("CyberslopStims-CorpoDaily_Active-Name", "Corpo Daily");
    this.Text("CyberslopStims-CorpoDaily_Active-Desc", "Daily stack. Hydration and Nutrition drain 15% slower, +5% health regeneration.");
    this.Text("CyberslopStims-Ketone_Active-Name", "Ketosis");
    this.Text("CyberslopStims-Ketone_Active-Desc", "Running on ketones. +15% stamina regeneration, +5 stamina.");
    this.Text("CyberslopStims-ColdBrew_Active-Name", "Executive Focus");
    this.Text("CyberslopStims-ColdBrew_Active-Desc", "Caffeine and theanine. Slightly faster aiming.");
    this.Text("CyberslopStims-NeuroSync_Active-Name", "NeuroSync");
    this.Text("CyberslopStims-NeuroSync_Active-Desc", "Myelin topped up. Sandevistan recharge and Kerenzikov cooldown 10% shorter, faster aiming.");
    this.Text("CyberslopStims-OsteoCal_Active-Name", "OsteoCal");
    this.Text("CyberslopStims-OsteoCal_Active-Desc", "Bone lacing supported. +25 carry capacity, +10 melee resistance.");
    this.Text("CyberslopStims-BioCoolant_Active-Name", "BioCoolant");
    this.Text("CyberslopStims-BioCoolant_Active-Desc", "Implants running cool. Faster RAM recovery, +20 thermal resistance.");
    this.Text("CyberslopStims-Rejectol_Active-Name", "Rejectol");
    this.Text("CyberslopStims-Rejectol_Active-Desc", "Immune system turned down. 15% less humanity damage, -5% health regeneration.");
    this.Text("CyberslopStims-Serene_Active-Name", "Serene");
    this.Text("CyberslopStims-Serene_Active-Desc", "Anxiolytic. Nerve rising steadily, steadier hands.");
    this.Text("CyberslopStims-ZeroPoint_Calm-Name", "Zero Point");
    this.Text("CyberslopStims-ZeroPoint_Calm-Desc", "Flat calm. Steadier hands, slightly slower aim and recovery.");
    this.Text("CyberslopStims-Respirocyte_Active-Name", "Respirocytes");
    this.Text("CyberslopStims-Respirocyte_Active-Desc", "Artificial red cells. 30% more oxygen reserve, 30% faster oxygen recovery, +5 stamina.");
    this.Text("CyberslopStims-Bronchodilator_Active-Name", "Open Airways");
    this.Text("CyberslopStims-Bronchodilator_Active-Desc", "Bronchodilated. 30% faster oxygen recovery, slightly shaky hands.");
    this.Text("CyberslopStims-Rapidetox_Nausea-Name", "Purged");
    this.Text("CyberslopStims-Rapidetox_Nausea-Desc", "Everything got flushed out at once. Nauseous, slower stamina recovery.");
    this.Text("CyberslopStims-Ghostline_Active-Name", "Off the Grid");
    this.Text("CyberslopStims-Ghostline_Active-Desc", "Ghostline is scrubbing your signals. Nobody tracks you down while you sleep in a vehicle.");
    this.Text("CyberslopStims-Emberline_Active-Name", "Emberline");
    this.Text("CyberslopStims-Emberline_Active-Desc", "Nicotine primed. Withdrawal suppressed, no smoker's debuff; smoking sharpens focus and halves Nerve loss.");
    this.Text("CyberslopStims-Emberline_Focus-Name", "Smoker's Focus");
    this.Text("CyberslopStims-Emberline_Focus-Desc", "Emberline and a lit cigarette. 20% less recoil, 20% faster aiming, 10% faster reloads, half of Nerve loss restored.");

    // ---------------------------------------------------------------- 1.2.0 humanity (Wannabe Edgerunner)
    this.Text("CyberslopStims-Anchor-Name", "Anchor Neural Integration Therapy");
    this.Text("CyberslopStims-Anchor-Desc", "Biotechnica's flagship for the heavily chromed: a 24-hour infusion of neurotrophic factors and an oxytocin analogue that teaches the brain to accept the metal as part of the self instead of fighting it. Corpo security leads get it on the company plan. Everyone else pays clinic price.\n\nRestores 10 Humanity at once and 1 more every hour. For 24 hours chrome and violence cost 40% less Humanity.\n\nThe price of feeling whole: a heavy, sedated calm, -10% stamina regeneration.");
    this.Text("CyberslopStims-Tether-Name", "Tether Mood Stabiliser");
    this.Text("CyberslopStims-Tether-Desc", "Lithium-class mood stabiliser reformulated for implant users: it smooths the spikes of rage and detachment that heavy chrome feeds. The daily pill of half the solos in Watson.\n\nRestores 3 Humanity. For 8 hours chrome and violence cost 20% less Humanity. No side effects worth mentioning.");
    this.Text("CyberslopStims-Lumen-Name", "Lumen Reconnection Therapy");
    this.Text("CyberslopStims-Lumen-Desc", "A psilocybin-derived therapy dose from the Biotechnica trauma programme: two hours of looking at your own life from the outside, the faces you forgot you cared about, the reasons you started. Take it somewhere safe, not before a job.\n\nRestores 15 Humanity over 2 hours.\n\nWhile it works your head is elsewhere: aiming 20% slower, 15% more recoil. Cannot be taken in combat.");
    this.Text("CyberslopStims-CircuitBreaker-Name", "Circuit Breaker Emergency Injector");
    this.Text("CyberslopStims-CircuitBreaker-Desc", "Trauma Team's psych-response autoinjector: a fast antipsychotic and a synaptic dampener that cut the feedback loop between the chrome and the fight-or-flight before it runs away. For the moment the edges of the world start going red. Usable in combat.\n\nStops an episode that is starting or running. For 15 minutes no Humanity damage and no episode. Restores 5 Humanity.\n\nThen the sedation: Nerve -10 and 1 hour of slow, heavy limbs (-30% stamina regeneration, slower aiming).");
    this.Text("CyberslopStims-KillSwitch-Name", "Kill Switch Psych-Ward Ampoule");
    this.Text("CyberslopStims-KillSwitch-Desc", "What MaxTac medics carry for the ones they want to bring in alive: haloperidol, dexmedetomidine and a neural blocker in one ampoule, enough to put a full borg on the floor. Sold out of the back of black-market clinics to people who know exactly what they are about to turn into. Usable in combat.\n\nStops any episode at once. For 1 hour no Humanity damage and no episode. Restores 20 Humanity.\n\nIt hits like a truck: Energy -30, Nerve -20, an hour of heavy sedation and then 2 hours of chemical straitjacket (-40% stamina regeneration, -20 stamina, aiming 25% slower).");
    this.Text("CyberslopStims-Anchor_Active-Name", "Anchor");
    this.Text("CyberslopStims-Anchor_Active-Desc", "The metal feels like part of you. 40% less Humanity damage, +1 Humanity every hour, -10% stamina regeneration.");
    this.Text("CyberslopStims-Tether_Active-Name", "Tether");
    this.Text("CyberslopStims-Tether_Active-Desc", "Mood held steady. 20% less Humanity damage.");
    this.Text("CyberslopStims-Lumen_Active-Name", "Lumen");
    this.Text("CyberslopStims-Lumen_Active-Desc", "Reconnecting. Humanity coming back; aiming slower, more recoil.");
    this.Text("CyberslopStims-CircuitBreaker_Active-Name", "Circuit Breaker");
    this.Text("CyberslopStims-CircuitBreaker_Active-Desc", "Feedback loop cut. No Humanity damage and no episode.");
    this.Text("CyberslopStims-CircuitBreaker_Sedation-Name", "Sedated");
    this.Text("CyberslopStims-CircuitBreaker_Sedation-Desc", "Coming down from the Circuit Breaker. -30% stamina regeneration, slower aiming.");
    this.Text("CyberslopStims-KillSwitch_Active-Name", "Kill Switch");
    this.Text("CyberslopStims-KillSwitch_Active-Desc", "Chemically held down. No Humanity damage and no episode; -20% stamina regeneration.");
    this.Text("CyberslopStims-KillSwitch_Straitjacket-Name", "Chemical Straitjacket");
    this.Text("CyberslopStims-KillSwitch_Straitjacket-Desc", "The Kill Switch wearing off. -40% stamina regeneration, -20 stamina, aiming 25% slower.");
    this.Text("CyberslopStims-Msg-Anchor", "the metal feels like yours again, until");
    this.Text("CyberslopStims-Msg-Tether", "mood held steady until");
    this.Text("CyberslopStims-Msg-Lumen", "reconnecting, until");
    this.Text("CyberslopStims-Msg-CircuitBreaker", "feedback loop cut, no episode until");
    this.Text("CyberslopStims-Msg-KillSwitch", "chemically held down until");
    this.Text("CyberslopStims-Msg-NoWE", "(Wannabe Edgerunner not running: no Humanity effect.)");
    this.Text("CyberslopStims-Msg-AnchorEnd", "Anchor wore off. The chrome is yours to carry alone again.");
    this.Text("CyberslopStims-Msg-CircuitBreakerEnd", "Circuit Breaker wearing off: the sedation sets in.");
    this.Text("CyberslopStims-Msg-KillSwitchEnd", "Kill Switch wearing off: chemical straitjacket for 2 hours.");

    // ---------------------------------------------------------------- Dark Future narcotic tooltips (1.1.1: aim speed, not crit)
    this.Text("CyberslopStims-DFNarcoticUIDesc", "Adds {int_0} - {int_1} stacks of <Rich color=\"MainColors.MildOrange\" style=\"Semi-Bold\">Overdrive</>. For each:\n  +{int_2} Nerve\n  +{int_3} temporary Energy\n  +{int_4}% Stamina Regen Rate\n  +{int_5}% Aim Speed");
    this.Text("CyberslopStims-DFNarcoticEffectDesc", "+{int_0} temporary Energy, +{int_1}% Stamina Regen Rate, +{int_2}% Aim Speed for each stack of this effect.");

    // ---------------------------------------------------------------- on-screen lines
    this.Text("CyberslopStims-Msg-Hold", "awake and sharp until");
    this.Text("CyberslopStims-Msg-Stacking", "Stacking stims: the crash will be heavier.");
    this.Text("CyberslopStims-Msg-Debt", "The stims wore off. Sleep debt:");
    this.Text("CyberslopStims-Msg-Energy", "Energy.");
    this.Text("CyberslopStims-Msg-Clean", "The stims wore off. Rested enough, no sleep debt.");
    this.Text("CyberslopStims-Msg-Kagami", "reflexes tuned until");
    this.Text("CyberslopStims-Msg-KagamiOverload", "Kagami: synaptic overload. Nothing gained, Nerve -20, the lag will be worse.");
    this.Text("CyberslopStims-Msg-KagamiEnd", "Kagami wore off. Neural Lag.");
    this.Text("CyberslopStims-Msg-Steady", "heart rate flat, Nerve held until");
    this.Text("CyberslopStims-Msg-Serene", "the dread is easing, until");
    this.Text("CyberslopStims-Msg-ZeroPoint", "flat calm until");
    this.Text("CyberslopStims-Msg-Lull", "lie down within the hour.");
    this.Text("CyberslopStims-Msg-LullSlept", "Lull: deep sleep. You wake up properly rested.");
    this.Text("CyberslopStims-Msg-LullDrowsy", "Lull: you fought the sleep aid. Drowsy until it wears off.");
    this.Text("CyberslopStims-Msg-Boost", "second processor online until");
    this.Text("CyberslopStims-Msg-BoostEnd", "Boost wore off. Migraine.");
    this.Text("CyberslopStims-Msg-Rapidetox", "purged. Stone sober, and nauseous.");
    this.Text("CyberslopStims-Msg-Antitox", "pretreated against toxins until");
    this.Text("CyberslopStims-Msg-Hardline", "nothing puts you down until");
    this.Text("CyberslopStims-Msg-HardlineEnd", "Hardline wore off. Adrenal crash.");
    this.Text("CyberslopStims-Msg-Respirocyte", "oxygen reserve boosted until");
    this.Text("CyberslopStims-Msg-Bronchodilator", "airways open until");
    this.Text("CyberslopStims-Msg-Ghostline", "off the grid until");
    this.Text("CyberslopStims-Msg-GhostlineEnd", "Ghostline burned out. You are back on the grid.");
    this.Text("CyberslopStims-Msg-Emberline", "nicotine primed until");
    this.Text("CyberslopStims-Msg-EmberlineEnd", "Emberline wore off. Smoking is just smoking again.");
    this.Text("CyberslopStims-Msg-ProteoMax", "well fuelled until");
    this.Text("CyberslopStims-Msg-Electra", "electrolytes balanced until");
    this.Text("CyberslopStims-Msg-CorpoDaily", "daily stack taken, covered until");
    this.Text("CyberslopStims-Msg-Ketone", "running on ketones until");
    this.Text("CyberslopStims-Msg-ColdBrew", "focused until");
    this.Text("CyberslopStims-Msg-NeuroSync", "myelin topped up until");
    this.Text("CyberslopStims-Msg-OsteoCal", "bone lacing supported until");
    this.Text("CyberslopStims-Msg-BioCoolant", "implants running cool until");
    this.Text("CyberslopStims-Msg-Rejectol", "immune system dialled down until");
  }
}

public class CyberslopMercStimsLocalization extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    return new CyberslopMercStimsTexts();
  }
  public func GetFallback() -> CName {
    return n"en-us";
  }
}
