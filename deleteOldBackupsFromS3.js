// eslint-disable-next-line @typescript-eslint/no-var-requires
const AWS = require('aws-sdk');
// eslint-disable-next-line @typescript-eslint/no-var-requires
const dateFns = require('date-fns')
// eslint-disable-next-line @typescript-eslint/no-var-requires
require('dotenv').config();

const endpoint = process.env.ENDPOINT; // Например, 'https://s3.solarcom.ch'
const accessKeyId = process.env.S3_ACCESS_KEY_ID;
const secretAccessKey = process.env.S3_SECRET_ACCESS_KEY;
const bucketName = process.env.BUCKET_NAME; // Убедитесь, что устанавливаете это значение в переменных окружения

const s3 = new AWS.S3({
    endpoint, // https://s3.solarcom.ch
    accessKeyId,
    secretAccessKey
});

const params = {
    Bucket: bucketName,
    Delimiter: '/',
    Prefix: '/'
};

s3.listObjectsV2(params, async function (err, data) {
    if (err) {
        console.log(err)
    } else {
        const threeDaysAgo = dateFns.subDays(new Date, 3);

        const oldBackups = data.Contents.filter(file => new Date(file.LastModified) < threeDaysAgo);

        for (const file of oldBackups) {
            const deleteParams = {
                Bucket: params.Bucket,
                Key: file.Key
            };

            await s3.deleteObject(deleteParams).promise();
            console.log(`Deleted ${file.Key}`);
        }

        if (oldBackups.length === 0) {
            console.log('No backups older than 3 days were found.');
        } else {
            console.log(`Deleted ${oldBackups.length} backups`);
        }
    }
})