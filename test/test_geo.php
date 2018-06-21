<html>
<body>
<?php

$geoip_country_code = getenv(HTTP_GEOIP_COUNTRY_CODE);
$geoip_country_code3 = getenv(HTTP_GEOIP_COUNTRY_CODE3);
$geoip_country_name = getenv(HTTP_GEOIP_COUNTRY_NAME);

$geoip_city_country_code = getenv(HTTP_GEOIP_CITY_COUNTRY_CODE);
$geoip_city_country_code3 = getenv(HTTP_GEOIP_CITY_COUNTRY_CODE3);
$geoip_city_country_name = getenv(HTTP_GEOIP_CITY_COUNTRY_NAME);
$geoip_region = getenv(HTTP_GEOIP_REGION);
$geoip_city = getenv(HTTP_GEOIP_CITY);
$geoip_postal_code = getenv(HTTP_GEOIP_POSTAL_CODE);
$geoip_city_continent_code = getenv(HTTP_GEOIP_CITY_CONTINENT_CODE);
$geoip_latitude = getenv(HTTP_GEOIP_LATITUDE);
$geoip_longitude = getenv(HTTP_GEOIP_LONGITUDE);

echo 'country_code: '.$geoip_country_code.'<br>';
echo 'country_code3: '.$geoip_country_code3.'<br>';
echo 'country_name: '.$geoip_country_name.'<br>';

echo 'city_country_code: '.$geoip_city_country_code.'<br>';
echo 'city_country_code3: '.$geoip_city_country_code3.'<br>';
echo 'city_country_name: '.$geoip_city_country_name.'<br>';
echo 'region: '.$geoip_region.'<br>';
echo 'city: '.$geoip_city.'<br>';
echo 'postal_code: '.$geoip_postal_code.'<br>';
echo 'city_continent_code: '.$geoip_city_continent_code.'<br>';
echo 'latitude: '.$geoip_latitude.'<br>';
echo 'longitude: '.$geoip_longitude.'<br>';

?>
</body>
</html>
