for entry in `ls`
do
echo "export * from './${entry/.ts/}'" >> index.ts
done
