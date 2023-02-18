for entry in `ls $1`
do
echo "export * from './${entry/.ts/}'" >> index.ts
done
