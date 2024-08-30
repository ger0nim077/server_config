<?php
// Configurable variables
$recipient = 'tvasile@gmail.com'; // Change this to your email address
$subjectUpdatesAvailable = 'Updates Available (APT and Snap)';
$subjectNoUpdates = 'No Updates Found (APT and Snap)';
$from = 'scraper@booksoft.ro'; // Change this to the "from" address

// Run apt update and apt list --upgradable
$updateCommand = 'DEBIAN_FRONTEND=noninteractive apt-get update 2>/dev/null';
$upgradeCommand = 'DEBIAN_FRONTEND=noninteractive apt list --upgradable 2>/dev/null';
exec($updateCommand, $updateOutput, $updateReturnVar);
exec($upgradeCommand, $upgradeOutput, $upgradeReturnVar);

// Check for Snap updates
$snapCommand = 'snap refresh --list 2>/dev/null';
exec($snapCommand, $snapOutput, $snapReturnVar);

// Prepare email headers
$headers = "From: " . $from . "\r\n";
$headers .= "Reply-To: " . $from . "\r\n";
$headers .= "X-Mailer: PHP/" . phpversion();

$updatesAvailable = false;
$message = "";

// Check for APT updates
if ($upgradeReturnVar == 0 && count($upgradeOutput) > 1) {
    $updatesAvailable = true;
    $message .= "APT Updates are available:\n\n" . implode("\n", array_slice($upgradeOutput, 1)) . "\n\n";
}

// Check for Snap updates
if ($snapReturnVar == 0 && count($snapOutput) > 0) {
    $updatesAvailable = true;
    $message .= "Snap Updates are available:\n\n" . implode("\n", $snapOutput) . "\n\n";
}

// Determine email subject and body
if ($updatesAvailable) {
    $subject = $subjectUpdatesAvailable;
} else {
    $subject = $subjectNoUpdates;
    $message = "There are no updates available at this time.";
}

// Send the email
mail($recipient, $subject, $message, $headers);
?>
