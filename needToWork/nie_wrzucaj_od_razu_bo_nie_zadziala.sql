-- phpMyAdmin SQL Dump
-- version 5.1.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Czas generowania: 23 Sie 2022, 15:37
-- Wersja serwera: 10.4.18-MariaDB
-- Wersja PHP: 8.1.2

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Baza danych: `es_extended`
--

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `gpt_announcements`
--

CREATE TABLE `gpt_announcements` (
  `id` int(11) NOT NULL,
  `content` longtext DEFAULT NULL,
  `expiry_date` varchar(50) DEFAULT NULL,
  `create_date` varchar(50) DEFAULT NULL,
  `author` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `gpt_cases`
--

CREATE TABLE `gpt_cases` (
  `id` int(11) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `status` varchar(255) NOT NULL DEFAULT 'false',
  `citizens` longtext DEFAULT '[]',
  `officers` longtext DEFAULT '[]',
  `vehicles` longtext DEFAULT '[]',
  `judgments` longtext DEFAULT '[]',
  `content` longtext DEFAULT NULL,
  `images` longtext DEFAULT '[]',
  `edit_date` varchar(50) DEFAULT NULL,
  `create_date` varchar(50) DEFAULT NULL,
  `author` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `gpt_citizens_notes`
--

CREATE TABLE `gpt_citizens_notes` (
  `id` int(11) NOT NULL,
  `ssn` varchar(46) DEFAULT NULL,
  `important` varchar(50) DEFAULT 'false',
  `content` longtext DEFAULT NULL,
  `create_time` varchar(50) DEFAULT NULL,
  `create_date` varchar(50) DEFAULT NULL,
  `author` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `gpt_citizens_wanted`
--

CREATE TABLE `gpt_citizens_wanted` (
  `id` int(11) NOT NULL,
  `ssn` varchar(46) DEFAULT NULL,
  `content` longtext DEFAULT NULL,
  `caseid` varchar(50) DEFAULT NULL,
  `expiry_date` varchar(50) DEFAULT NULL,
  `create_date` varchar(50) DEFAULT NULL,
  `author` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `gpt_judgments`
--

CREATE TABLE `gpt_judgments` (
  `id` int(11) NOT NULL,
  `ssn` varchar(46) DEFAULT NULL,
  `reason` longtext DEFAULT NULL,
  `bill` varchar(255) DEFAULT NULL,
  `time` varchar(255) DEFAULT NULL,
  `case` varchar(255) DEFAULT NULL,
  `create_time` varchar(50) DEFAULT NULL,
  `create_date` varchar(50) DEFAULT NULL,
  `author` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `gpt_licenses`
--

CREATE TABLE `gpt_licenses` (
  `name` varchar(255) DEFAULT NULL,
  `owner` varchar(46) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `gpt_vehicles_notes`
--

CREATE TABLE `gpt_vehicles_notes` (
  `id` int(11) NOT NULL,
  `vin` varchar(17) DEFAULT NULL,
  `important` varchar(50) DEFAULT 'false',
  `content` longtext DEFAULT NULL,
  `create_time` varchar(50) DEFAULT NULL,
  `create_date` varchar(50) DEFAULT NULL,
  `author` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `gpt_vehicles_wanted`
--

CREATE TABLE `gpt_vehicles_wanted` (
  `id` int(11) NOT NULL,
  `vin` varchar(17) DEFAULT NULL,
  `content` longtext DEFAULT NULL,
  `caseid` varchar(255) DEFAULT 'Brak',
  `expiry_date` varchar(50) DEFAULT NULL,
  `create_date` varchar(50) DEFAULT NULL,
  `author` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `gpt_weapons`
--

CREATE TABLE `gpt_weapons` (
  `id` int(11) NOT NULL,
  `owner` varchar(46) DEFAULT NULL,
  `serial_number` varchar(255) DEFAULT NULL,
  `model` varchar(255) DEFAULT NULL,
  `purchase` varchar(50) DEFAULT '1/09/1939'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Zrzut danych tabeli `jobs`
--

INSERT INTO `jobs` (`name`, `label`, `whitelisted`) VALUES
('offpolice', 'PoliseOwełDuty', 0);

--
-- Zrzut danych tabeli `job_grades`
--

INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES
('offpolice', 0, 'employee', 'Poza Służbą', 0, '', '');

--
-- Zrzut danych tabeli `licenses`
--

INSERT INTO `licenses` (`type`, `label`) VALUES
('police_eagle', 'Licencja Eagle'),
('police_seu', 'Licencja S.E.U');

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `owned_vehicles`
--

CREATE TABLE `owned_vehicles` (
  `owner` varchar(46) DEFAULT NULL,
  `plate` varchar(12) NOT NULL,
  `vehicle` longtext DEFAULT NULL,
  `type` varchar(20) NOT NULL DEFAULT 'car',
  `job` varchar(20) DEFAULT NULL,
  `stored` tinyint(4) NOT NULL DEFAULT 0,
  `parking` varchar(60) DEFAULT NULL,
  `pound` varchar(60) DEFAULT NULL,
  `vin` varchar(17) NOT NULL,
  `ssn` int(11) NOT NULL,
  `cossn` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Struktura tabeli dla tabeli `users`
--

CREATE TABLE `users` (
  `identifier` varchar(46) NOT NULL,
  `accounts` longtext DEFAULT NULL,
  `group` varchar(50) DEFAULT 'user',
  `inventory` longtext DEFAULT NULL,
  `job` varchar(20) DEFAULT 'unemployed',
  `job_grade` int(11) DEFAULT 0,
  `loadout` longtext DEFAULT NULL,
  `position` varchar(255) DEFAULT '{"x":-269.4,"y":-955.3,"z":31.2,"heading":205.8}',
  `firstname` varchar(16) DEFAULT NULL,
  `lastname` varchar(16) DEFAULT NULL,
  `dateofbirth` varchar(10) DEFAULT NULL,
  `sex` varchar(1) DEFAULT NULL,
  `height` int(11) DEFAULT NULL,
  `skin` longtext DEFAULT NULL,
  `status` longtext DEFAULT NULL,
  `is_dead` tinyint(1) DEFAULT 0,
  `id` int(11) NOT NULL,
  `disabled` tinyint(1) DEFAULT 0,
  `last_property` varchar(255) DEFAULT NULL,
  `phone_number` int(11) DEFAULT NULL,
  `ssn` int(11) NOT NULL,
  `badge` int(11) NOT NULL,
  `dutyTime` varchar(50) NOT NULL DEFAULT '00:00:00',
  `lastOnDuty` varchar(50) DEFAULT NULL,
  `image` varchar(8192) NOT NULL DEFAULT 'public/img/citizen-picture-none.png'
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

--
-- Indeksy dla zrzutów tabel
--

--
-- Indeksy dla tabeli `gpt_announcements`
--
ALTER TABLE `gpt_announcements`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `gpt_cases`
--
ALTER TABLE `gpt_cases`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `gpt_citizens_notes`
--
ALTER TABLE `gpt_citizens_notes`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `gpt_citizens_wanted`
--
ALTER TABLE `gpt_citizens_wanted`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `gpt_judgments`
--
ALTER TABLE `gpt_judgments`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `gpt_vehicles_notes`
--
ALTER TABLE `gpt_vehicles_notes`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `gpt_vehicles_wanted`
--
ALTER TABLE `gpt_vehicles_wanted`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `gpt_weapons`
--
ALTER TABLE `gpt_weapons`
  ADD PRIMARY KEY (`id`);

--
-- Indeksy dla tabeli `owned_vehicles`
--
ALTER TABLE `owned_vehicles`
  ADD PRIMARY KEY (`plate`);

--
-- Indeksy dla tabeli `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`identifier`) USING BTREE,
  ADD UNIQUE KEY `id` (`id`),
  ADD UNIQUE KEY `index_users_phone_number` (`phone_number`);

--
-- AUTO_INCREMENT dla zrzuconych tabel
--

--
-- AUTO_INCREMENT dla tabeli `gpt_announcements`
--
ALTER TABLE `gpt_announcements`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT dla tabeli `gpt_cases`
--
ALTER TABLE `gpt_cases`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT dla tabeli `gpt_citizens_notes`
--
ALTER TABLE `gpt_citizens_notes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT dla tabeli `gpt_judgments`
--
ALTER TABLE `gpt_judgments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT dla tabeli `gpt_vehicles_notes`
--
ALTER TABLE `gpt_vehicles_notes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT dla tabeli `gpt_weapons`
--
ALTER TABLE `gpt_weapons`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT dla tabeli `users`
--
ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
