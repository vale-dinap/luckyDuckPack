/////////////////////////////////////////////////////
/////////////////////////////////////////////////////
/////////////////////////////////////////////////////

const fs = require("fs");

// Source database files to be processed and combined
//old/const sourceFile = "C:/Users/valer/Desktop/LuckyDuckPack_generative/build/json/_metadata_IPFS.json";
const hashFile = "C:/Users/valer/OneDrive/Documents/GitHub/luckyDucksPack/misc/NFT_metadata/hashes.json";
const sourceFile = "C:/Users/valer/OneDrive/Documents/GitHub/luckyDucksPack/misc/NFT_metadata/_metadata_v2.json";

const destPath = "C:/Users/valer/Desktop/_metadata_hashes_.json";

function addValue(database){
    var updated = JSON.parse(
        JSON.stringify(database)
        .replaceAll("mystring", "MyString")
    );
    return updated;
}

function addTrait(database, index, traitIndex, traitName, traitValue){
    traitData = {trait_type: traitName, value: traitValue};
    tokenData = database[index];
    numTraits = Object.keys(tokenData.attributes).length
    preArray = []
    postArray = []
    if(traitIndex>=0){
        for(let i=0; i<traitIndex; ++i){
            preArray.push(tokenData.attributes[i]);
        }
        for(let j=traitIndex; j<numTraits; ++j){
            postArray.push(tokenData.attributes[j]);
        }
    }
    else if(traitIndex==-1){
        preArray = tokenData.attributes;
    }
    newArray = [...preArray, traitData, ...postArray];
    tokenData.attributes = newArray;
    database[index] = tokenData;
    return database;
}

function addPostprocessTraits(database, postDatabase){
    let post_keys = Object.keys(postDatabase);
    //console.log(post_keys);
    for(let i=0; i<database.length; ++i){
        tokenId = database[i].token_id;
        for(let j=0; j<post_keys.length; ++j){
            let value = postDatabase[post_keys[j]][tokenId];
            //console.log(value);
            if (value!="none"){
                let traitIndex = 0;
                if(post_keys[j]=="Background" && getCaseValue(database, i).includes("Cables")){
                    value="Black";
                }
                if(post_keys[j]=="Background"){ traitIndex = 0; }
                else if(post_keys[j]=="Overlay"){ traitIndex = -1; }
                database = addTrait(database, i, traitIndex, post_keys[j], value)
            }
        }
    }
    return database;
}

function truncateDatabase(database, amount){
    return database.slice(0, amount);
}

data = require(sourceFile);
hashes = require(hashFile);
let newData = [];
for(let x=0; x<data.length; ++x){
    let provenance = '29c8c78a66ee0edd9d8825f9cc02fe8ed0b58f5e0c2bc8a89ae5be08f74ae077';
    let tempData = JSON.stringify(data[x]);
    let hash = hashes[x];
    let manipData = tempData.replace('.png",', '.png","image_file_hash":"'+hash+'","collection_provenance_hash":"'+provenance+'",');
    //let manipData = tempData.replace('.png",', '.png","image_alternative_location":"ARWEAVEMANIFEST/'+x+'.png",');
    //let manipData = tempData.replace('.png","image_alternative_location":"ipfs://bafybeicjl7jihwko5xjm4ehxqusugcuofd2vfepxv6ya6lfc5toviafvfu/'+x+'.png",', '.png",');
    //if(x==0) console.log(tempData);
    //if(x==0) console.log(manipData);
    newData.push(JSON.parse(manipData));
}
console.log(data[0]);
console.log("---------------");
console.log(newData[0]);

fs.writeFileSync(destPath, JSON.stringify(newData, null, "  "));
//let concatHashes = "";
//for(let x=0; x<10000; ++x){
//    concatHashes+=hashes[x];
//}
//console.log(concatHashes);

/*function processAllAndExport(){
    let allData = processAllEditions();
    allData = addIPFSpath(allData, imagedir_ipfs);
    fs.writeFileSync(destPath, JSON.stringify(allData, null, "  "));
}*/

/*
// TEST //
let finalDatabase = processAllEditions();
finalDatabase = addIPFSpath(finalDatabase, imagedir_ipfs);
console.log(finalDatabase[3401]);
*/

//processAllAndExport();

/*function extractFiles (source, destPath) {

    const data = require(source);

    for(let i=0; i<data.length; ++i){
        let edition = data[i].edition;
        fs.writeFileSync(destPath+edition, JSON.stringify(data[i], null, "  "));
    }
}

extractFiles(sourceFile, destPath);*/