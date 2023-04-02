const fs = require("fs");

const sourceFile = "C:/Users/valer/Desktop/LuckyDuckPack_generative/build/json/_metadata.json";
//const destPath = process.env.TOKENMETADATA_DESTINATION_PATH;

function buildTraitsDict(traitsArray){
    let dict = {};
    for(let index=0; index<traitsArray.length; ++index){
        dict[traitsArray[index].trait_type] = traitsArray[index].value;
    }
    return dict;
}

function checkSimilar (source) {

    function compareTraits(arrayA, arrayB, ignoreList){
        let match=true;
            let a_traitsDict = buildTraitsDict(arrayA);
            let b_traitsDict = buildTraitsDict(arrayB);
            for(let i=0; i<arrayA.length; ++i){
                let traitName = arrayA[i].trait_type;
                if(!ignoreList.includes(traitName)){
                    if(b_traitsDict.traitName!=undefined || a_traitsDict[traitName]!=b_traitsDict[traitName]){
                            match=false;
                    }
                }
            }
        return match;
    }

    function checkOffendingMatches(traitsA, traitsB, traitsToCheck, offendingValues){
        let dictA = buildTraitsDict(traitsA);
        let dictB = buildTraitsDict(traitsB);
        for(let i=0; i<traitsToCheck.length; ++i){
            traitToCheck = traitsToCheck[i];
            valueA = dictA[traitToCheck];
            valueB = dictB[traitToCheck];
            valuesToCheck = offendingValues[traitToCheck];
            for(let v=0; v<valuesToCheck.length; ++v){
                //console.log(valuesToCheck[v]);
                if(valuesToCheck[v].includes(valueA) && valuesToCheck[v].includes(valueB)){
                    return true;
                }
            }
        }
        return false;
    }

    const data = require(source);
    let all_found = {};
    let numFound = 0;
    let ignoreTraits = ["Background"];
    let offendingTraits = {"Background":[["Light Green", "Salmon Pink", "Silver Pink", "Purple", "Light Grey", "Light Blue", "Lavender", "Aquamarine"]]}

    console.log("Scanned traits: "+ignoreTraits);
    console.log("Offending values (considered visually similar): "+JSON.stringify(offendingTraits, null, "  "));

    for(let i=0; i<data.length; ++i){
        //console.log("Checking item "+i.toString());
        let found = [];
        let edition = data[i].edition;
        let i_traits = data[i].attributes;
        for(let x=0; x<data.length; ++x){
            //process.stdout.write("Comparing with item "+x.toString());
            if(i!=x){
                let x_traits = data[x].attributes;
                let match = compareTraits(i_traits, x_traits, ignoreTraits);
                if(match==true){
                    if(all_found[data[x].edition]===undefined || !all_found[data[x].edition].includes(edition)){
                        let hasOffendingMatches = checkOffendingMatches(i_traits, x_traits, ignoreTraits, offendingTraits);
                        if(hasOffendingMatches){
                            found.push(data[x].edition);
                            numFound++;
                        }
                        //found.push(data[x].edition);
                    }
                }
            }
        }
        if(found.length>0){
            all_found[edition] = found;
            //console.log("Found matches for token "+edition+": "+found);
        }
        //fs.writeFileSync(destPath+edition, JSON.stringify(data[i], null, "  "));
    }
    console.log("Found matches: "+JSON.stringify(all_found, null, "  "));
    console.log("Number of occurrencies found: "+numFound.toString());
}

function listAllTraits(source){
    const data = require(source);
    let traits = [];
    for(let i=0; i<data.length; ++i){
        //console.log("Checking item "+i);
        let traitsArray = data[i].attributes;
        for(let index=0; index<traitsArray.length; ++index){
            let name = traitsArray[index].trait_type;
            if(!traits.includes(name)){
                traits.push(name);
            }
        }
    }
    let values = {};
    for(let traitId=0; traitId<traits.length; ++traitId){
        let variations = [];
        for(let i=0; i<data.length; ++i){
            let value = buildTraitsDict(data[i].attributes)[traits[traitId]];
            if(!variations.includes(value)){
                variations.push(value);
            }
        }
        values[traits[traitId]] = variations;
    }
    console.log("Traits full list: "+JSON.stringify(traits, null, "  "));
    console.log("Variations full list: "+JSON.stringify(values, null, "  "));
}

listAllTraits(sourceFile);
checkSimilar(sourceFile);