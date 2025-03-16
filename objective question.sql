use ipl;
show tables;

-- Q1.List the different dtypes of columns in table “ball_by_ball” (using information schema)
SELECT 
    COLUMN_NAME, 
    DATA_TYPE 
FROM 
    INFORMATION_SCHEMA.COLUMNS 
WHERE 
    TABLE_NAME = 'ball_by_ball';
    

-- Q2.What is the total number of runs scored in 1st season by RCB (bonus: also include the extra runs using the extra runs table).

WITH extra_run_data AS (
SELECT
 Team_Batting AS team_Id,
 SUM(e.Extra_Runs) as total_extra
FROM ball_by_ball b
JOIN extra_runs e ON e.Match_Id = b.Match_Id AND e.Innings_No = b.Innings_No AND e.Over_Id = b.Over_Id AND e.Ball_Id = b.Ball_Id 
WHERE Team_Batting = 2
AND b.Match_Id IN( 
    SELECT distinct Match_Id FROM matches WHERE Season_Id = ( SELECT MIN(Season_Id) as first_season FROM Matches WHERE Team_1 = 2 OR Team_2 = 2))
),

run_scored_data AS (
SELECT
Team_Batting AS team_Id,
 SUM(b.Runs_Scored) AS total_score
FROM ball_by_ball b
JOIN matches m ON m.Match_Id = b.Match_Id
  WHERE Team_Batting = 2 AND (Team_1 = 2 OR Team_2 = 2) AND m.Season_Id = ( SELECT MIN(Season_Id) as first_season FROM Matches WHERE Team_1 = 2 OR Team_2 = 2)
)    

SELECT 
   (total_score + total_extra) AS total_runs
FROM run_scored_data s
JOIN extra_run_data e ON e.team_Id = s.team_Id;
   
   
-- Q3. How many players were more than the age of 25 during season 2014?    

SELECT 
   COUNT(*) AS player_above_25
from player
WHERE TIMESTAMPDIFF(YEAR, DOB,  (SELECT MIN(Match_Date) FROM matches WHERE YEAR(Match_Date) = 2014 )) > 25 ;

-- Q4. How many matches did RCB win in 2013? 
SELECT 
     COUNT(*) as total_match,
     SUM( CASE WHEN Match_Winner = 2 THEN 1 ELSE 0 END) AS total_win
FROM matches 
     WHERE YEAR(Match_Date) = 2013 AND (Team_1 = 2 or Team_2 = 2);  


-- Q5. List the top 10 players according to their strike rate in the last 4 seasons  

WITH recent_seasons AS (
    SELECT s.Season_Id
    FROM season s
    ORDER BY s.Season_Id DESC
    LIMIT 4
),
recent_matches AS (
    SELECT m.Match_Id
    FROM matches m
    WHERE m.Season_Id IN (SELECT Season_Id FROM recent_seasons)
)
SELECT 
    p.Player_Id AS player_id,
    p.Player_Name AS player_name,
    ROUND(100.0 * SUM(b.Runs_Scored) / COUNT(b.Runs_Scored),2) AS strike_rate
FROM player p
JOIN ball_by_ball b ON b.Striker = p.Player_Id
WHERE b.Match_Id IN (SELECT Match_Id FROM recent_matches)
AND NOT EXISTS (
    SELECT 1
    FROM extra_runs e
    WHERE b.Match_Id = e.Match_Id
      AND b.Over_Id = e.Over_Id
      AND b.Ball_Id = e.Ball_Id
      AND e.Extra_Type_Id NOT IN(1,3)
      AND b.Innings_No = e.Innings_No
) 
GROUP BY p.Player_Id, p.Player_Name
HAVING COUNT(b.Runs_Scored) >= 500
ORDER BY strike_rate DESC
LIMIT 10;

-- Q6. What are the average runs scored by each batsman considering all the seasons?

WITH grouped_data AS (
SELECT  
 b.Match_Id,
 p.Player_Name,
 p.Player_Id,
 SUM(b.Runs_Scored) AS batsman_total_score
FROM player p
JOIN ball_by_ball b ON b.Striker = p.Player_Id
AND NOT EXISTS (
    SELECT 1
    FROM extra_runs e
    WHERE b.Match_Id = e.Match_Id
      AND b.Over_Id = e.Over_Id
      AND b.Ball_Id = e.Ball_Id
      AND e.Extra_Type_Id NOT IN(1,3)
      AND b.Innings_No = e.Innings_No
) 
GROUP BY p.Player_Id, p.Player_Name, b.Match_Id)

SELECT 
    Player_Id, 
    Player_Name, 
    ROUND(AVG(batsman_total_score), 2) AS avg_score 
FROM grouped_data 
    GROUP BY Player_Id, Player_Name
	HAVING SUM(batsman_total_score) > 500
    ORDER BY avg_score DESC;
    
-- Q7.What are the average wickets taken by each bowler considering all the seasons?  

WITH grouped_data AS (
SELECT 
    m.Season_Id,
	b.Bowler AS Player_Id,
    p.Player_Name,
	COUNT(*) AS total_wicket
FROM wicket_taken w 
JOIN ball_by_ball b 
	ON w.Match_Id = b.Match_Id 
	AND w.Over_Id = b.Over_Id
	AND w.Ball_Id = b.Ball_Id 
	AND w.Innings_No = b.Innings_No
JOIN player p ON p.Player_Id = b.Bowler 
JOIN matches m ON m.Match_Id = w.Match_Id   
   WHERE w.Kind_Out != 3 
   GROUP BY b.Bowler, p.Player_Name, m.Season_Id
   )
   
SELECT 
	Player_Id,
    Player_Name,
	ROUND(AVG(total_wicket), 2) AS avg_wicket
FROM grouped_data  
   GROUP BY Player_Id, Player_Name
   ORDER BY avg_wicket DESC ;
 
 
-- Q8. List all the players who have average runs scored greater than the overall average and who have taken wickets greater than the overall average

WITH player_wickets AS (
 SELECT 
        b.Bowler AS Player_Id,
        b.Match_Id,
        COUNT(*) AS total_wicket
   FROM wicket_taken w 
   JOIN ball_by_ball b 
        ON w.Match_Id = b.Match_Id 
        AND w.Over_Id = b.Over_Id
        AND w.Ball_Id = b.Ball_Id 
        AND w.Innings_No = b.Innings_No
   WHERE w.Kind_Out != 3 
   GROUP BY b.Bowler, b.Match_Id
   ),

player_avg_wicket AS (
SELECT 
     Player_Id,
     ROUND(AVG(total_wicket), 2) AS avg_wicket
FROM player_wickets 
GROUP BY Player_Id
),
player_runs AS (
	 SELECT  
            b.Match_Id,
            p.Player_Name,
            p.Player_Id,
            SUM(b.Runs_Scored) AS batsman_total_score
     FROM player p
	 JOIN ball_by_ball b ON b.Striker = p.Player_Id
     AND NOT EXISTS (
    SELECT 1
    FROM extra_runs e
    WHERE b.Match_Id = e.Match_Id
      AND b.Over_Id = e.Over_Id
      AND b.Ball_Id = e.Ball_Id
      AND e.Extra_Type_Id NOT IN(1,3)
      AND b.Innings_No = e.Innings_No
) 
      GROUP BY p.Player_Id, p.Player_Name, b.Match_Id
) ,

player_avg_run AS (
SELECT 
  Player_Id,
  Player_Name, 
  ROUND(AVG(batsman_total_score), 2) as avg_run
FROM player_runs pr
GROUP BY Player_Id, Player_Name
)

SELECT 
    r.Player_Id,
    Player_Name,
	r.avg_run,
    w.avg_wicket
FROM player_avg_run r
JOIN player_avg_wicket w  ON w.Player_Id = r.Player_Id
WHERE avg_run > (SELECT ROUND(AVG(avg_run),2) FROM player_avg_run )
AND avg_wicket > (SELECT ROUND(AVG(avg_wicket),2) FROM player_avg_wicket)
ORDER BY avg_run DESC,  avg_wicket DESC; 

-- Q9.Create a table rcb_record table that shows the wins and losses of RCB in an individual venue.

SELECT 
  v.Venue_Id,
  v.Venue_Name,
  COUNT(v.Venue_Id) AS total_matches,
  SUM( CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END ) AS total_win,
  SUM( CASE WHEN m.Match_Winner != 2 THEN 1 ELSE 0 END ) AS total_loss,
  COUNT(v.Venue_Id) - ( SUM( CASE WHEN m.Match_Winner = 2 THEN 1 ELSE 0 END ) + SUM( CASE WHEN m.Match_Winner != 2 THEN 1 ELSE 0 END )) AS `no_result/draw`
FROM venue v
JOIN matches m ON m.Venue_Id = v.Venue_Id
WHERE (Team_1 = 2 OR Team_1 = 2)
GROUP BY v.Venue_Id, v.Venue_Name ;

-- Q10. What is the impact of bowling style on wickets taken?

WITH player_bowlling_Style AS (
   SELECT 
       p.player_Id,
       p.player_Name,
       bs.Bowling_Id,
       bs.Bowling_skill
   FROM player p 
   JOIN bowling_style bs ON bs.Bowling_Id = p.Bowling_skill
),

group_bowler_wicket AS (    
   SELECT 
        b.Bowler AS Player_Id,
        COUNT(*) AS total_wicket
   FROM wicket_taken w 
   JOIN ball_by_ball b 
        ON w.Match_Id = b.Match_Id 
        AND w.Over_Id = b.Over_Id
        AND w.Ball_Id = b.Ball_Id 
        AND w.Innings_No = b.Innings_No
    WHERE w.Kind_Out != 3    
   GROUP BY b.Bowler
)
SELECT 
      pb.Bowling_Id,
      pb.Bowling_skill,
     SUM(gb.total_wicket) AS total_wicket,
     ROUND( 100 * SUM(gb.total_wicket) / (SELECT SUM(total_wicket) FROM group_bowler_wicket), 2) AS total_wicket_percentage
FROM group_bowler_wicket gb
JOIN player_bowlling_Style pb ON gb.Player_Id = pb.Player_Id 
GROUP BY pb.Bowling_Id, pb.Bowling_skill
ORDER BY total_wicket DESC;

-- Q11. Write the SQL query to provide a status of whether the performance of the team is better than the previous year's 
-- performance on the basis of the number of runs scored by the team in the season and the number of wickets taken ?
select distinct Season_Id from matches;

WITH team_run_details AS (
   SELECT 
	     m.Season_Id,
         t.Team_Id,
         t.Team_Name,
         SUM(b.Runs_Scored) AS total_run
   FROM ball_by_ball b
   JOIN team t ON b.Team_Batting = t.Team_Id
   JOIN matches m ON m.Match_Id = b.Match_Id
         GROUP BY   t.Team_Id, t.Team_Name, m.Season_Id 
         ORDER BY t.Team_Id, m.Season_Id desc 
),

team_wicket_details AS(
   SELECT 
        b.Team_Bowling AS team_Id,
        m.Season_Id,
        COUNT(*) AS total_wicket
   FROM wicket_taken w 
   JOIN ball_by_ball b 
        ON w.Match_Id = b.Match_Id 
        AND w.Over_Id = b.Over_Id
        AND w.Ball_Id = b.Ball_Id 
        AND w.Innings_No = b.Innings_No
    JOIN matches m ON m.Match_Id = b.Match_Id    
       GROUP BY b.Team_Bowling, m.Season_Id
       ORDER BY team_Id, m.Season_Id DESC
   ),
 grouped_data AS (
 SELECT 
      tr.Season_Id AS season,
      tr.Team_Id,
      tr.Team_Name,
      tr.total_run,
      COALESCE(LEAD(tr.total_run) OVER(PARTITION BY tr.Team_Id ORDER BY tr.Team_Id, tr.Season_Id DESC ), 0) AS previous_season_run, 
      tw.total_wicket,
      COALESCE(LEAD(tw.total_wicket) OVER(PARTITION BY tr.Team_Id ORDER BY tr.Team_Id, tr.Season_Id DESC),0) AS previous_season_wicket
 FROM team_wicket_details tw
 JOIN team_run_details tr ON tr.team_Id = tw.team_Id AND tr.Season_Id = tw.Season_Id
 )
 
 SELECT 
      season,
      Team_Id,
      Team_Name,
      total_run,
      previous_season_run,
     (CASE 
         WHEN total_run > previous_season_run AND previous_season_run != 0 THEN "Better"
         WHEN previous_season_run = 0 THEN "Not played Previous Season"
         ELSE "Worse" 
	  END ) AS batting_status,
     total_wicket,
     previous_season_wicket,
     ( CASE 
          WHEN total_wicket > previous_season_wicket AND previous_season_wicket != 0 THEN "Better" 
          WHEN previous_season_wicket = 0 THEN "Not played Previous Season"
          ELSE "Worse" 
	 END ) AS bowling_status,
	 ( CASE 
          WHEN total_wicket > previous_season_wicket AND total_run > previous_season_run AND previous_season_run != 0 AND previous_season_wicket != 0 THEN "Better" 
          WHEN ((total_wicket < previous_season_wicket) AND  (total_run > previous_season_run)) OR ((total_wicket > previous_season_wicket) AND (total_run < previous_season_run)) AND previous_season_run != 0 AND previous_season_wicket != 0 THEN "Good"
          WHEN previous_season_wicket = 0 AND previous_season_run = 0 THEN "Not played Previous Season"
	 ELSE "Worse" END ) AS overall_status
FROM grouped_data;   


-- Q 13. Using SQL, write a query to find out the average wickets taken by each bowler in each venue. Also, rank the gender according to the average value.

WITH player_per_match_wicket AS (
  SELECT 
        b.Match_Id,
        b.Bowler AS Player_Id,
        p.Player_Name,
        COUNT(*) AS total_wicket
   FROM wicket_taken w 
   JOIN ball_by_ball b 
        ON w.Match_Id = b.Match_Id 
        AND w.Over_Id = b.Over_Id
        AND w.Ball_Id = b.Ball_Id 
        AND w.Innings_No = b.Innings_No
    JOIN player p ON p.Player_Id = b.Bowler
	WHERE w.Kind_Out != 3 
   GROUP BY b.Bowler,b.Match_Id
)

SELECT 
      m.Venue_Id,
      v.Venue_Name,
      p.Player_Id,
      p.Player_Name,
      ROUND(AVG(p.total_wicket), 2) AS avg_wicket,
      ROW_NUMBER() OVER(PARTITION BY m.Venue_Id ORDER BY SUM(p.total_wicket) DESC ,AVG(p.total_wicket) DESC ) AS rnk
FROM player_per_match_wicket p 
JOIN matches m ON m.Match_Id = p.Match_Id
JOIN venue v ON m.Venue_Id = v.Venue_Id
GROUP BY m.Venue_Id, p.Player_Id, v.Venue_Name, p.Player_Name;

-- Q14. Which of the given players have consistently performed well in past seasons?

-- top 10 consistant player in all season with their run and strike rate
WITH batsman_season_runs AS (
SELECT 
     m.Season_Id, 
     p.Player_Id, 
     p.Player_Name,
     COUNT(DISTINCT m.Match_Id) AS total_Match,
     SUM(b.Runs_Scored) AS total_run,
     100 * SUM(b.Runs_Scored) / COUNT(b.Runs_Scored) AS strike_rate,
     COUNT(DISTINCT m.Match_Id) as match_count
FROM ball_by_ball b
JOIN player p ON p.Player_Id = b.Striker
JOIN matches m ON m.Match_Id = b.Match_Id
WHERE NOT EXISTS (
    SELECT 1
    FROM extra_runs e
    WHERE b.Match_Id = e.Match_Id
      AND b.Over_Id = e.Over_Id
      AND b.Ball_Id = e.Ball_Id
      AND e.Extra_Type_Id NOT IN(1,3)
      AND b.Innings_No = e.Innings_No
) 
GROUP BY p.Player_Name, p.Player_Id, m.Season_Id
)

SELECT 
     Player_Id,
     Player_Name,
     SUM(total_Match) AS total_match,
     COUNT(DISTINCT Season_Id) AS total_season,
     SUM(total_run) AS total_run,
     ROUND(AVG(strike_rate), 2) AS strike_rate
FROM batsman_season_runs
     GROUP BY Player_Id, Player_Name
     HAVING COUNT(DISTINCT Season_Id) > 3
     ORDER BY total_run DESC, strike_rate DESC, total_season DESC
     LIMIT 10;

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
     COUNT(DISTINCT Season_Id) AS total_season,
     SUM(total_wicket) AS total_wicket,
     ROUND(SUM(total_ball) / SUM(total_wicket), 2) AS bowling_strike_rate
FROM bolwer_season_wicket
GROUP BY Bowler, Player_Name
HAVING COUNT(DISTINCT Season_Id) >= 3
ORDER BY total_wicket DESC ,total_match DESC, bowling_strike_rate 
LIMIT 10;


-- Q. 15 Are there players whose performance is more suited to specific venues or conditions?

-- WITH batsman_fev_venue AS (
SELECT
    m.Venue_Id,
    v.Venue_Name,
    b.Striker AS player_Id,
    p.Player_Name,
    SUM(b.Runs_Scored) AS total_run,
    COUNT( DISTINCT m.Match_Id) AS total_match,
    ROUND(SUM(b.Runs_Scored) / COUNT( DISTINCT m.Match_Id), 2) AS avg_venue_run,
    ROUND(100 * SUM(b.Runs_Scored) / COUNT(b.Runs_Scored), 2) AS strike_rate
FROM ball_by_ball b
JOIN matches m ON b.Match_Id = m.Match_Id
JOIN player p ON p.Player_Id = b.Striker
JOIN venue v ON v.Venue_Id = m.Venue_Id
WHERE NOT EXISTS (
    SELECT 1
    FROM extra_runs e
    WHERE b.Match_Id = e.Match_Id
      AND b.Over_Id = e.Over_Id
      AND b.Ball_Id = e.Ball_Id
      AND e.Extra_Type_Id NOT IN(1,3)
      AND b.Innings_No = e.Innings_No
) 
GROUP BY b.Striker, m.Venue_Id, p.Player_Name
HAVING SUM(b.Runs_Scored) > 200
ORDER BY total_run DESC, avg_venue_run DESC, total_match DESC;


SELECT 
v.Venue_Id,
v.Venue_Name,
b.Bowler AS Player_Id,
p.Player_Name,
COUNT( DISTINCT b.Match_Id) AS total_matches,
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
LEFT JOIN venue v ON v.Venue_Id = m.Venue_Id
	 GROUP BY b.Bowler, v.Venue_Id, v.Venue_Name, p.Player_Name
ORDER BY total_wicket DESC, total_matches DESC;     




