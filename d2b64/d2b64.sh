res=''

for path in $(find $1 -type f)
do
  content=$(cat $path)
  res=$res$content
done

echo $res | base64
