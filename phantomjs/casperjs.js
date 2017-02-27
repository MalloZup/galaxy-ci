var casper = require('casper').create({   
    verbose: true, 
    logLevel: 'debug',
    pageSettings: {
         loadImages:  true,         // The WebPage instance used by Casper will
         loadPlugins: false,         // use these settings
         userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.94 Safari/537.4'
    }
});

// print out all the messages in the headless browser context
casper.on('remote.message', function(msg) {
    this.echo('remote message caught: ' + msg);
});

casper.on('resource.error', function(msg) {
    this.echo("g_____________________________________");
    this.echo(msg.errorString);
    this.echo(msg.id + " URL"+ msg.url);
});
// print out all the messages in the headless browser context
casper.on("page.error", function(msg, trace) {
    this.echo("Page Error: " + msg, "ERROR");
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
   console.log("======================================================");
   console.log("Page Title " + document.title);
   console.log("Your name is " + document.querySelector('.headerTinymanName').textContent ); 
   console.log("******** GOING TO LOAD MINION RMT PAGE");
});

casper.thenOpen('https://headref-suma3pg.mgr.suse.de/rhn/manager/minions/cmd', function() {
   this.capture('test.png')
   console.log("******** MINION PAGE **********");
   this.click("button[id='preview']")
   });

casper.run();
