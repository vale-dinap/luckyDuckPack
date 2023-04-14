// Extract a single JSON file per token from the metadata database file
// Files are named as the "edition" value, with no extension

const fs = require("fs");
require('dotenv').config();

const sourceFile = process.env.TOKENMETADATA_DATABASE_LOCATION;
const destPath = process.env.EXTRACTEDMETADATA_DESTINATION_PATH;

function extractFiles (source, destPath) {

    const data = require(source);

    for(let i=0; i<data.length; ++i){
        let edition = data[i].edition;
        fs.writeFileSync(destPath+edition, JSON.stringify(data[i], null, "  "));
    }
}

extractFiles(sourceFile, destPath);