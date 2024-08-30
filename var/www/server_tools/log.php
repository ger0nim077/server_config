<?php

// List of file paths for the log files
$logFiles = [
    '/var/www/html/booksoft.ro/auctiondb/logs/mysqli_errors.log', //AuctionDB logs
    '/var/www/html/booksoft.ro/diverse/astro/logs/mysqli_errors.log', //Astro logs
    '/var/www/html/booksoft.ro/scraper/logs/mysqli_errors.log', //Book scraper general logs
    '/var/www/html/booksoft.ro/scraper/logs/scraperH_errors.log', //Okazii Historic logs
    '/var/www/html/booksoft.ro/scraper/logs/scraperOK_errors.log', //Okazii scraper logs
    '/var/www/html/primapagina.ro/logs/mysqli_errors.log', //News logs

    '/var/www/html/booksoft.ro/scraper/logs/curl_errors.log', //Book scraper curl request

    '/var/log/letsencrypt/letsencrypt.log', //Letsencrypt certificates log

    '/var/log/mysql/error.log', //MariaDB logs
    '/var/log/mysqld.log', //MariaDB logs

    '/var/log/nginx/access.log', //Nginx logs
    '/var/log/fail2ban.log', //Fail2ban logs
    '/var/log/mail.log', //Mail logs

    '/var/log/php8.3-fpm.log', //Php-fpm logs
    '/var/www/BACKUP/errors.log' //Backup script logs

    // '/var/log/mysql-slow.log'
    // '/var/log/cron'
];

$outputFile = '/var/www/html/combined_logs.txt'; // File to store the concatenated logs

// Open the output file for writing
if ($handle = fopen($outputFile, 'w')) {

    foreach ($logFiles as $logFile) {
        if (file_exists($logFile) && is_readable($logFile)) {
            // Get the last modification time of the file
            $fileDateTime = new DateTime();
            $fileDateTime->setTimestamp(filemtime($logFile));
            $dateTimeFormatted = $fileDateTime->format('Y-m-d H:i:s');

            // Prepare the header information
            $headerInfo = "---- Log from: {$logFile} at {$dateTimeFormatted} ----\n";
            // Write the header information to the output file
            if (fwrite($handle, $headerInfo) === false) {
                echo "Cannot write to the output file: {$outputFile}\n";
                continue; // Skip this file and move to the next one
            }
            // Echo the header information
            echo $headerInfo;

            // Open the log file for reading
            $logHandle = fopen($logFile, 'r');
            if ($logHandle) {
                while (($line = fgets($logHandle)) !== false) {
                    // Write the current line to the output file
                    fwrite($handle, $line);
                    // Optionally, echo the line for output
                    echo $line;
                }
                fclose($logHandle);
                // Add an extra newline for separation between logs in the output
                fwrite($handle, "\n");
                echo "\n";
            } else {
                echo "Cannot read log file: {$logFile}\n";
            }
        } else {
            echo "Cannot read log file: {$logFile}\n";
        }
    }

    if (ob_get_level() > 0) {
        ob_flush(); // Flush output buffer if active
    }
    flush(); // Flush system output buffer

    // Close the output file handle
    fclose($handle);
    echo "Logs have been combined into {$outputFile}";
    
} else {
    echo "Cannot open the output file for writing.";
}

?>
