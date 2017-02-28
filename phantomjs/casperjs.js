var casper = require('casper').create({   
    verbose: true, 
    logLevel: 'debug',
});

casper.userAgent("Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/28.0.1500.71 Safari/537.36");

// print out all the messages in the headless browser context
casper.on('remote.message', function(msg) {
    this.echo('remote message caught: ');
    console.log(msg);
});

casper.on('resource.error', function(msg) {
    this.echo("RESOURCE_ERROR________________________________");
    console.log(msg.errorString);
    console.log("err code:" + msg.errorCode + " URL:"+ msg.url);
});

casper.on('resource.timeout', function(msg) {
    this.echo("____RESOURCE_TIMEOUT___________");
    this.echo(msg.errorString);
    this.echo("err code:" + msg.errorCode + " URL:"+ msg.url);
});

// print out all the messages in the headless browser context
casper.on("page.error", function(msg, trace) {
    this.echo("Page Error: " + msg, "ERROR");
    this.echo("Page Error Trace: " + trace, "ERROR");
});

var url = 'https://headref-suma3pg.mgr.suse.de/rhn/Login.do';

casper.start(url, function() {
   console.log("page loaded");
   casper.waitForSelector("input[id='username-field']", function() {
   console.log("********");
   this.sendKeys("input[id='username-field']", 'admin');
   this.sendKeys("input[id='password-field']", 'admin');
   this.click("input[id='login']")
   console.log("********");
});
});

casper.thenEvaluate(function(){
   console.log("Page Title " + document.title);
   console.log("Your name is " + document.querySelector('.headerTinymanName').textContent ); 
   console.log("******** GOING TO LOAD MINION RMT PAGE");
});

casper.thenOpen('https://headref-suma3pg.mgr.suse.de/rhn/manager/minions/cmd', function() {
    casper.waitForText("Preview targets", function() {
            console.log("******** MINION PAGE **********");
            this.click("button[id='preview']")
            this.capture('test.png')
    });
});

casper.run();
