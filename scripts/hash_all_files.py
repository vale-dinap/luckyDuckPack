### This uses sha256 to generate the hash of each file ###
import hashlib, os, csv

def getFromDotenv(var_name):
    with open('.env') as dotenv:
        for line in dotenv.readlines():
            if var_name in line:
                value = line.split("=")[-1].strip('\n "')
        return(value)

tokenmetadata_files_folder = getFromDotenv("TOKENMETADATA_DESTINATION_PATH")
tokenmedia_files_folder = getFromDotenv("TOKENMEDIA_PATH")
hash_folder = getFromDotenv("HASH_PATH")

#print(metadata_files_folder)
#print(metadata_hash_folder)

def hashString(stringToHash):
    hash=hashlib.sha256()
    hash.update(stringToHash.encode("UTF-8"))
    return hash.hexdigest()

def sha256(filename):
    hash_sha256 = hashlib.sha256()
    with open(filename, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_sha256.update(chunk)
    return hash_sha256.hexdigest()

def hash_all(folder, fileExt, iterations):
    #files=sorted(os.listdir(folder))
    hashes = {}
    for i in range(0, iterations, 1):
        file = folder+str(i)+"."+fileExt
        #print("working on file "+file)
        hash = sha256(file)
        #print(hash)
        hashes.update({i:hash})
    return hashes

def hashAll_and_save(alias, folder, fileExt, dest_folder, iterations):
    ### create destination folder if doesnt exist ###
    if not os.path.exists(dest_folder):
        os.mkdir(dest_folder)
    else:
        pass
    ### File name path prefix ###
    prefix = dest_folder+alias+"_"+fileExt+"_hash"
    ### Get data to be written ###
    # All hashes
    hashesDict=hash_all(folder, fileExt, iterations)
    # Concatenated hashes
    hashes_concat = ""
    for k in hashesDict:
        hashes_concat+=hashesDict[k]
    # Hash of hashes
    hash_of_hashes = hashString(hashes_concat)
    ### Write files ###
    # CSV
    csvPath = prefix+".csv"
    with open(csvPath, mode='w') as csv_file:
        data = csv.writer(csv_file, dialect='excel', delimiter=';', quotechar='"', lineterminator="\n")
        data.writerow(["token id", alias+" hash (sha256)"])
        for i in hashesDict:
            data.writerow([i, hashesDict[i]])
    # TXT (one hash per line)
    with open(prefix+".txt", mode='w') as txt_file:
        data_txt = ""
        for j in hashesDict:
            if j>1:
                data_txt+="\n"
            data_txt+=hashesDict[j]
        txt_file.write(data_txt)
    # TXT (concatenated hashes)
    with open(prefix+"_all_concat.txt", mode='w') as concat_txt_file:
        concat_txt_file.write(hashes_concat)
    # TXT (hash of all concatenated hashes)
    with open(prefix+"_of_hashes.txt", mode='w') as hash_of_hashes_txt_file:
        hash_of_hashes_txt_file.write(hash_of_hashes)
    ### Return data ###
    return {"dictionary": hashesDict, "concatenated": hashes_concat, "hashOfAll": hash_of_hashes}

def hashListString(list):
    concat=list.replace("\n", "")
    #print(concat)
    return hashString(concat)

def getListFromTxtFile(file):
    with open(file, "r") as f:
        return f.read()



#token_metadata_hashes = hashAll_and_save("tokenMetadata", tokenmetadata_files_folder, "", hash_folder, 10000)
#token_media_hashes = hashAll_and_save("tokenMedia", tokenmedia_files_folder, "png", hash_folder, 10000)
token_media_hashes = hash_all(tokenmedia_files_folder, "png", 10000)
print(token_media_hashes)
#print("Hash of [concatenated metadata file hashes]: "+token_metadata_hashes["hashOfAll"])
#print("Hash of [concatenated media file hashes]: "+token_media_hashes["hashOfAll"])
'''
provenanceHash = hashString(token_metadata_hashes["hashOfAll"]+token_media_hashes["hashOfAll"])
with open(hash_folder+"PROVENANCE.txt", mode='w') as provenanceFile:
    provenanceFile.write(provenanceHash)
print("FINAL PROVENANCE HASH: "+provenanceHash)
'''