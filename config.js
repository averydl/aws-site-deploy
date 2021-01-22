var prompt = require('prompt');
var fs = require('fs');
var colors = require('colors/safe');

const fName = 'config.json' // do not change; this is read by serverless directly

// prompts to define required project configuration fields
var configSchema = {
    properties: {
        overwrite: {
            description: colors.red(`a file ${fName} already exists - do you want to overwrite it? (y/n)`),
            pattern: '[yn]{1}',
            message: colors.yellow('please enter "y" for yes, or "n" for "no"'),
            ask: () => {return fs.existsSync(fName)},
        },
        projectname: {
            description: 'the name of this serverless project (e.g. personal-site)\nrequired',
            required: true,
            ask: () => {return !prompt.history('overwrite') || prompt.history('overwrite').value != 'n'},
        },
        domain: {
            description: 'your Route53 domain (e.g. example.com)\nrequired',
            required: true,
            ask: () => {return !prompt.history('overwrite') || prompt.history('overwrite').value != 'n'},
        },
        zoneid: {
            description: 'id of your domain\'s hosted zone (e.g. Z2FDTNDATAQYW2)\nrequired',
            required: true,
            ask: () => {return !prompt.history('overwrite') || prompt.history('overwrite').value != 'n'},
        },
        logprefix: {
            description: 'prefix added to logs written to log bucket (e.g. logs/)\noptional',
            required: false,
            ask: () => {return !prompt.history('overwrite') || prompt.history('overwrite').value != 'n'},
        },
        rootobject: {
            description: 'default object returned at root domain (e.g. index.html)\noptional',
            required: false,
            ask: () => {return !prompt.history('overwrite') || prompt.history('overwrite').value != 'n'},
        }
    }
}

prompt.start()

// write results to config file
prompt.get(configSchema, (err, result) => {
    // abort if user does not want to overwrite existing file
    if(result.overwrite == 'n') {
        console.log('Aborting configuration...');
        return;
    }
    delete result.overwrite

    fs.writeFileSync(fName, JSON.stringify(result, null, '\t'))
    console.log('configuration complete:')
    console.log('the following values were set in config.json:\n')
    console.log(JSON.stringify(result, null, '\t'))
})
