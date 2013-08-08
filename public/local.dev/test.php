<?php

if ('cli' != PHP_SAPI) {
	die(0);
}


$t = microtime(true);
file_put_contents(__DIR__ . '/1.tmp', '');
$str = str_repeat(' ', 1024 * 1024);
$limit = 100;
while ($limit > 0) {
	file_put_contents(__DIR__ . '/1.tmp', $str, FILE_APPEND);
	$limit--;
}

echo 'write: ' . round(microtime(true) - $t, 3) . ' end' . PHP_EOL;

$t = microtime(true);
$fp = fopen(__DIR__ . '/1.tmp', 'rb');
while (!feof($fp)) {
	fread($fp, 1024 * 1024);
}
echo 'read: ' . round(microtime(true) - $t, 3) . ' end' . PHP_EOL;

$t = microtime(true);
$limit = 100000;
while ($limit > 0) {
	$a = sin(deg2rad(round(rand(1, 180))));
	$limit--;
}
echo 'sin: ' . round(microtime(true) - $t, 3) . ' end' . PHP_EOL;

unlink(__DIR__ . '/1.tmp');
