-- Q1. How does the toss decision affect the result of the match? (which visualizations could be used to present your answer better) And is the impact limited to only specific venues?

SELECT
 m.Venue_Id,
 v.Venue_Name,
 t.Toss_Name,
 COUNT(*) AS total_match,
 SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) AS total_win,
ROUND(100*  SUM(CASE WHEN Toss_Winner = Match_Winner THEN 1 ELSE 0 END) / COUNT(*), 2)  AS win_percentage
FROM matches m
JOIN toss_decision t ON t.Toss_Id = m.Toss_Decide
JOIN venue v ON v.venue_Id = m.Venue_Id 
GROUP BY t.Toss_Name, m.Venue_Id, v.Venue_Name
ORDER BY m.Venue_Id, win_percentage DESC;


-- Q2 Suggest some of the players who would be best fit for the team.

-- top 10 batsman 
SELECT 
     p.Player_Id, 
     p.Player_Name,
     COUNT(DISTINCT m.Match_Id) AS total_Match,
     SUM(b.Runs_Scored) AS total_run,
    ROUND( 100 * SUM(b.Runs_Scored) / COUNT(b.Runs_Scored), 2) AS strike_rate
FROM ball_by_ball b
JOIN player p ON p.Player_Id = b.Striker
JOIN matches m ON m.Match_Id = b.Match_Id
GROUP BY p.Player_Name, p.Player_Id
ORDER BY total_run DESC, strike_rate DESC
LIMIT 10;

-- top 10 bowler
WITH bolwer_season_wicket AS (
SELECT 
m.Season_Id,
b.Bowler,
p.Player_Name,
COUNT( DISTINCT b.Match_Id) AS total_matches,
COUNT( b.Match_Id ) as total_ball,
COUNT(w.Match_Id) as total_wicket 
FROM ball_by_ball b
LEFT JOIN wicket_taken w 
	 ON w.Match_Id = b.Match_Id 
	 AND w.Over_Id = b.Over_Id
	 AND w.Ball_Id = b.Ball_Id 
	 AND w.Innings_No = b.Innings_No
     AND w.Kind_Out != 3
LEFT JOIN player p ON p.Player_Id = b.Bowler
LEFT JOIN Matches m ON m.Match_Id = b.Match_Id
	 GROUP BY b.Bowler, m.Season_Id, p.Player_Name
   )

SELECT 
     Bowler AS Player_Id,
     Player_Name,
     SUM(total_matches) AS total_match,
     SUM(total_wicket) AS total_wicket,
     ROUND(SUM(total_ball) / SUM(total_wicket), 2) AS bowling_strike_rate
FROM bolwer_season_wicket
GROUP BY Bowler, Player_Name
HAVING COUNT(DISTINCT Season_Id) >= 3
ORDER BY total_wicket DESC ,total_match DESC, bowling_strike_rate 
LIMIT 10;


-- Q3. What are some of the parameters that should be focused on while selecting the players?

WITH economy_grouped_data AS (
  SELECT 
   b.Bowler,
   p.Player_Name,
   m.Season_Id,
   m.Match_Id,
   COUNT( DISTINCT b.Over_Id) AS total_over,
   SUM(b.Runs_Scored) AS total_runs_conceded, 
   SUM(b.Runs_Scored) / COUNT( DISTINCT b.Over_Id) as overall_economy,
   SUM(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN b.Runs_Scored ELSE 0 END) AS runs_conceded_death_overs, 
   SUM(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN b.Runs_Scored ELSE 0 END) / COUNT( distinct CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN b.Over_Id END ) AS death_over_economy  FROM ball_by_ball b
  JOIN matches m ON m.Match_Id = b.Match_Id 
  JOIN player p ON p.Player_Id = b.Bowler
  GROUP BY b.Bowler, m.Season_Id, m.Match_Id, p.Player_Name
)

SELECT 
  Bowler,
  Player_Name,
  ROUND(AVG(total_runs_conceded), 2) AS avg_total_runs_conceded,
  ROUND(AVG(overall_economy), 2) AS avg_overall_economy,
  ROUND(AVG(runs_conceded_death_overs), 2) AS avg_runs_conceded_death_overs,
  ROUND(AVG(death_over_economy), 2) AS avg_death_over_economy
FROM economy_grouped_data
GROUP BY Bowler, Player_Name
 HAVING SUM(total_over) > 50
ORDER BY avg_death_over_economy, avg_overall_economy;

WITH wicket_grouped_data AS (
  SELECT
    m.Match_Id,
    m.Season_Id,
    b.Bowler,
    p.Player_Name,
    COUNT(*) AS total_wickets,
    COALESCE(SUM(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN 1 END), 0) AS wickets_death_overs
  FROM ball_by_ball b
  JOIN matches m ON m.Match_Id = b.Match_Id
  JOIN wicket_taken w 
    ON w.Match_Id = b.Match_Id 
    AND w.Over_Id = b.Over_Id
    AND w.Ball_Id = b.Ball_Id 
    AND w.Innings_No = b.Innings_No  
  JOIN player p ON p.Player_Id = b.Bowler  
  GROUP BY m.Match_Id, m.Season_Id, b.Bowler, p.Player_Name
)

SELECT 
  Bowler,
  Player_Name,
  SUM(total_wickets) AS total_wicket,
  ROUND(AVG(total_wickets), 2) AS avg_total_wickets,
  ROUND(AVG(wickets_death_overs), 2) AS avg_wickets_death_overs
FROM wicket_grouped_data
GROUP BY Bowler, Player_Name
HAVING SUM(total_wickets) >= 50
ORDER BY avg_wickets_death_overs DESC, avg_total_wickets DESC;

WITH run_group_data AS (
SELECT
    b.Striker,
    p.Player_Name,
    m.Season_Id,
    m.Match_Id,
    SUM(b.Runs_Scored) AS total_runs,
    SUM(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN b.Runs_Scored ELSE 0 END) AS death_overs_runs,
    COUNT(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN 1 END) AS total_ball,
    ROUND(100 * SUM(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN b.Runs_Scored ELSE 0 END)  / COUNT(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN 1 END), 2) AS strike_rate
FROM ball_by_ball b
JOIN matches m ON m.Match_Id = b.Match_Id
JOIN player p ON p.Player_Id = b.Striker
WHERE NOT EXISTS (
    SELECT 1
    FROM extra_runs e
    WHERE b.Match_Id = e.Match_Id
      AND b.Over_Id = e.Over_Id
      AND b.Ball_Id = e.Ball_Id
      AND e.Extra_Type_Id NOT IN(1,3)
      AND b.Innings_No = e.Innings_No
) 
GROUP BY m.Match_Id, m.Season_Id, b.Striker,p.Player_Name
)

SELECT
    Striker AS Player_Id,
    Player_Name,
    SUM(total_runs) AS total_runs,
    ROUND(SUM(death_overs_runs), 2) AS avg_death_overs_runs, 
    ROUND(AVG(strike_rate), 2) AS strike_rate
FROM run_group_data
GROUP BY Player_Id,  Player_Name
HAVING SUM(total_runs) > 100 AND sum(total_ball) > 50
ORDER BY strike_rate DESC;

-- Q4. Which players offer versatility in their skills and can contribute effectively with both bat and ball? (can you visualize the data for the same)

WITH player_wickets AS (
 SELECT 
        b.Bowler AS Player_Id,
        COUNT(w.Match_Id) AS total_wicket,
        ROUND(COUNT(b.Match_Id) / COUNT(w.Match_Id), 2) AS Bowling_Strike_Rate
FROM ball_by_ball b 
LEFT JOIN wicket_taken w 
        ON w.Match_Id = b.Match_Id 
        AND w.Over_Id = b.Over_Id
        AND w.Ball_Id = b.Ball_Id 
        AND w.Innings_No = b.Innings_No
        AND w.Kind_Out != 3 
   GROUP BY b.Bowler
   ),
   
player_runs AS (
	 SELECT  
		  p.Player_Name,
		  p.Player_Id,
		  SUM(b.Runs_Scored) AS total_run,
         ROUND(100 * SUM(b.Runs_Scored) / COUNT(b.Runs_Scored),2) AS batting_strike_rate
     FROM player p
	 JOIN ball_by_ball b ON b.Striker = p.Player_Id
     WHERE NOT EXISTS (
    SELECT 1
    FROM extra_runs e
    WHERE b.Match_Id = e.Match_Id
      AND b.Over_Id = e.Over_Id
      AND b.Ball_Id = e.Ball_Id
      AND e.Extra_Type_Id NOT IN(1,3)
      AND b.Innings_No = e.Innings_No
) 
	GROUP BY p.Player_Id, p.Player_Name
) 
SELECT  
     r.Player_Id,
     r.Player_Name,
     r.total_run,
     w.total_wicket,
     r.batting_strike_rate,
     w.Bowling_Strike_Rate
FROM player_runs r
JOIN player_wickets w ON w.Player_Id = r.Player_Id
     WHERE r.total_run >= (SELECT AVG(total_run) FROM player_runs )
     AND w.total_wicket >= (SELECT AVG(total_wicket) FROM player_wickets )
     ORDER BY r.total_run DESC, w.total_wicket DESC
     LIMIT 10;


-- Q5. Are there players whose presence positively influences the morale and performance of the team?
WITH player_win_percentage AS (
SELECT 
	p.Player_Id,
	p.Player_Name, 
	pm.Team_Id,
	t.Team_Name,
	COUNT(m.Match_Id) AS Total_Matches, 
	SUM(CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END) AS Matches_Won,
	ROUND( 100 * SUM(CASE WHEN m.Match_Winner = pm.Team_Id THEN 1 ELSE 0 END) /  COUNT(m.Match_Id), 2) AS win_percentage
FROM player p
JOIN player_match pm ON p.Player_Id = pm.Player_Id
JOIN matches m ON pm.Match_Id = m.Match_Id
JOIN team t ON t.Team_Id = pm.Team_Id
    WHERE m.Outcome_type = 1
    GROUP BY p.Player_Id, p.Player_Name, pm.Team_Id, t.Team_Name
    HAVING count(m.Match_Id) > 10
    -- ORDER BY win_percentage DESC
)

SELECT 
     Player_Id,
     Player_Name,
     SUM(Total_Matches) AS Total_Matches,
     SUM(Matches_Won) AS Matches_Won,
     ROUND(AVG(win_percentage), 2) AS win_percentage
FROM  player_win_percentage
     GROUP BY  Player_Id, Player_Name 
     ORDER BY win_percentage DESC; 
     
-- Q. 7 What do you think could be the factors contributing to the high-scoring matches and the impact on viewership and team strategies     
SELECT
    m.Match_Id,
    SUM(b.Runs_Scored) AS match_total_run
FROM ball_by_ball b
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN venue v ON v.Venue_Id = m.Venue_Id
GROUP BY m.Match_Id
HAVING SUM(b.Runs_Scored) >= 350
ORDER BY match_total_run DESC;     
     
-- Q.8 Analyze the impact of home-ground advantage on team performance and identify strategies to maximize this advantage for RCB.
  
WITH filtered_data AS (
SELECT 
   (
   CASE 
    WHEN v.Venue_Id = 5 THEN 1 WHEN v.Venue_Id = 1 THEN 2
    WHEN v.Venue_Id = 8 THEN 3 WHEN v.Venue_Id = 2 THEN 4 
    WHEN v.Venue_Id = 6 THEN 5 WHEN v.Venue_Id = 3 THEN 6
    WHEN v.Venue_Id = 4 THEN 7 WHEN v.Venue_Id = 7 THEN 11
   END ) AS Team_Id ,
  v.Venue_Id,
  v.Venue_Name,
  m.Match_Winner
FROM venue v
JOIN matches m ON m.Venue_Id = v.Venue_Id
WHERE ((m.Team_1 = 1 OR m.Team_2 = 1 ) AND v.Venue_Id = 5) OR ((m.Team_1 = 2 OR m.Team_2 = 2 ) AND v.Venue_Id = 1)
OR ((m.Team_1 = 3 OR m.Team_2 = 3 ) AND v.Venue_Id = 8) OR ((m.Team_1 = 4 OR m.Team_2 = 4 ) AND v.Venue_Id = 2)
OR ((m.Team_1 = 5 OR m.Team_2 = 5 ) AND v.Venue_Id = 6) OR ((m.Team_1 = 6 OR m.Team_2 = 6 ) AND v.Venue_Id = 3)
OR ((m.Team_1 = 7 OR m.Team_2 = 7 ) AND v.Venue_Id = 4) OR ((m.Team_1 = 11 OR m.Team_2 = 11 ) AND v.Venue_Id = 7)
)

SELECT 
     Venue_Id,
     Venue_Name,
     f.Team_Id,
     t.Team_Name,
     count(Match_Winner) as total_match,
     SUM( CASE WHEN f.Team_Id = f.Match_Winner THEN 1 ELSE 0 END) AS total_win,
     ROUND(100 * SUM( CASE WHEN f.Team_Id = f.Match_Winner THEN 1 ELSE 0 END) / count(Match_Winner), 2) AS win_percentage
FROM filtered_data f
JOIN team t ON t.Team_Id = f.Team_Id
GROUP BY  Venue_Id, Venue_Name, f.Team_Id, t.Team_Name 
ORDER BY win_percentage DESC;

-- Q.9 Come up with a visual and analytical analysis of the RCB's past season's performance and potential reasons for them not winning a trophy.

-- rcb batting stats 
WITH batting_group_data AS (
  SELECT 
    m.Season_Id,
    m.Match_Id,
    SUM(b.Runs_Scored) AS total_runs,
    SUM(CASE WHEN b.Over_Id BETWEEN 1 AND 6 THEN b.Runs_Scored ELSE 0 END) AS first_powerplay_runs,
    SUM(CASE WHEN b.Over_Id BETWEEN 7 AND 14 THEN b.Runs_Scored ELSE 0 END) AS middle_overs_runs,
    SUM(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN b.Runs_Scored ELSE 0 END) AS death_overs_runs
  FROM ball_by_ball b
  JOIN matches m ON m.Match_Id = b.Match_Id
  WHERE (m.Team_1 = 2 OR m.Team_2 = 2) AND b.Team_Batting = 2
  GROUP BY m.Season_Id, m.Match_Id
)

SELECT 
  Season_Id,
  ROUND(AVG(total_runs), 2) AS avg_total_runs,
  ROUND(AVG(first_powerplay_runs), 2) AS avg_first_powerplay_runs,
  ROUND(AVG(first_powerplay_runs) / 6, 2) AS avg_first_powerplay_economy,
  ROUND(AVG(middle_overs_runs), 2) AS avg_middle_overs_runs,
  ROUND(AVG(middle_overs_runs) / 8, 2) AS avg_middle_overs_economy,
  ROUND(AVG(death_overs_runs), 2) AS avg_death_overs_runs,
  ROUND(AVG(death_overs_runs) / 6, 2) AS avg_death_overs_economy
FROM batting_group_data
GROUP BY Season_Id;

WITH economy_grouped_data AS (
  SELECT 
    m.Season_Id,
    m.Match_Id,
    SUM(b.Runs_Scored) AS total_runs_conceded,
    SUM(CASE WHEN b.Over_Id BETWEEN 1 AND 6 THEN b.Runs_Scored ELSE 0 END) AS runs_conceded_first_powerplay,
    SUM(CASE WHEN b.Over_Id BETWEEN 7 AND 14 THEN b.Runs_Scored ELSE 0 END) AS runs_conceded_middle_overs,
    SUM(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN b.Runs_Scored ELSE 0 END) AS runs_conceded_death_overs
  FROM ball_by_ball b
  JOIN matches m ON m.Match_Id = b.Match_Id
  WHERE (m.Team_1 = 2 OR m.Team_2 = 2) AND b.Team_Bowling = 2
  GROUP BY m.Season_Id, m.Match_Id
)

SELECT 
  Season_Id,
  ROUND(AVG(total_runs_conceded), 2) AS avg_total_runs_conceded,
  ROUND(AVG(runs_conceded_first_powerplay), 2) AS avg_runs_conceded_first_powerplay,
  ROUND(AVG(runs_conceded_first_powerplay) / 6, 2) AS first_powerplay_economy,
  ROUND(AVG(runs_conceded_middle_overs), 2) AS avg_runs_conceded_middle_overs,
  ROUND(AVG(runs_conceded_middle_overs) / 8, 2) AS middle_overs_economy,
  ROUND(AVG(runs_conceded_death_overs), 2) AS avg_runs_conceded_death_overs,
  ROUND(AVG(runs_conceded_death_overs) / 6, 2) AS death_overs_economy
FROM economy_grouped_data
GROUP BY Season_Id;

WITH wicket_grouped_data AS (
  SELECT
    m.Match_Id,
    m.Season_Id,
    COUNT(*) AS total_wickets,
    COALESCE(SUM(CASE WHEN b.Over_Id BETWEEN 1 AND 6 THEN 1 END), 0) AS wickets_first_powerplay,
    COALESCE(SUM(CASE WHEN b.Over_Id BETWEEN 7 AND 14 THEN 1 END), 0) AS wickets_middle_overs,
    COALESCE(SUM(CASE WHEN b.Over_Id BETWEEN 15 AND 20 THEN 1 END), 0) AS wickets_death_overs
  FROM ball_by_ball b
  JOIN matches m ON m.Match_Id = b.Match_Id
  JOIN wicket_taken w 
    ON w.Match_Id = b.Match_Id 
    AND w.Over_Id = b.Over_Id
    AND w.Ball_Id = b.Ball_Id 
    AND w.Innings_No = b.Innings_No
  WHERE (m.Team_1 = 2 OR m.Team_2 = 2) AND b.Team_Bowling = 2     
  GROUP BY m.Match_Id, m.Season_Id
)

SELECT 
  Season_Id,
  ROUND(AVG(total_wickets), 2) AS avg_total_wickets,
  ROUND(AVG(wickets_first_powerplay), 2) AS avg_wickets_first_powerplay,
  ROUND(AVG(wickets_middle_overs), 2) AS avg_wickets_middle_overs,
  ROUND(AVG(wickets_death_overs), 2) AS avg_wickets_death_overs
FROM wicket_grouped_data
GROUP BY Season_Id;

-- Q. 11 In the "Match" table, some entries in the "Opponent_Team" column are incorrectly spelled as "Delhi_Capitals" instead of "Delhi_Daredevils". Write an SQL query to replace all occurrences of "Delhi_Capitals" with "Delhi_Daredevils".

SET SQL_SAFE_UPDATES = 0;

UPDATE Team
SET Team_Name = "Delhi Daredevils"
WHERE Team_Name = "Delhi Capitals";