var backgroundJobProgressTimer = 0;
var jobID = '';
var savedForm;
var inBackgroundJobProgressTimer = false;
var i = 0;
function updateJobProgress() {
    if (inBackgroundJobProgressTimer) {
        return;
    }
    i = i+1;
    inBackgroundJobProgressTimer = true;
    $.getJSON("/cgi-bin/koha/svc/background_job_status?job_id=" + encodeURIComponent(jobID) + '&amp;i='+i, function(json) {
        var percentage = json.percentage;
        var bgproperty = (parseInt(percentage*2)-300)+"px 0px";
        $("#jobprogress").css("background-position",bgproperty);
        $("#jobprogresspercent").text(percentage);

        console.log(i + ' : ' + percentage);
        if (percentage == 100) {
            clearInterval(backgroundJobProgressTimer); // just in case form submission fails
            completeJob();
        }
        inBackgroundJobProgressTimer = false;
    });
}

function completeJob() {
    console.log("job complete");
    savedForm.completedJobID.value = jobID;
    savedForm.submit();
}

// submit a background job with data
// supplied from form f and activate
// progress indicator
function submitBackgroundJob(f) {
    // check for background field
    if (f.runinbackground) {
        // set value of this hidden field for
        // use by CGI script
        savedForm = f;
        f.mainformsubmit.disabled = true;
        f.runinbackground.value = 'true';

        // gather up form submission
        var inputs = [];
        $(':input', f).each(function() {
            if (this.type == 'radio' || this.type == 'checkbox') {
                if (this.checked) {
                    inputs.push(this.name + '=' + encodeURIComponent(this.value));
                }
            } else if (this.type == 'button') {
                ; // do nothing
            } else {
                inputs.push(this.name + '=' + encodeURIComponent(this.value));
            }

        });

        // and submit the request
        $("#jobpanel").show();
        $("#jobstatus").show();
        $.ajax({
            data: inputs.join('&'),
            url: '/cgi-bin/koha/svc/background_job_start',
            dataType: 'json',
            type: 'post',
            success: function(json) {
                jobID = json.job_id;
                inBackgroundJobProgressTimer = false;
                backgroundJobProgressTimer = setInterval("updateJobProgress()", 500);
            },
            error: function(xml, textStatus) {
                alert('Failed to submit form: ' + textStatus);
            }

        });

    } else {
        // background job support not enabled,
        // so just do a normal form submission
        f.submit();
    }

    return false;
}
