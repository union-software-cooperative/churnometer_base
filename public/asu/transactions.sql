SELECT
	[ReceiptNo] ID
	,[TimeCreated] CreationDate
	,[MemberID]
	,[UserID]
	,[ReceiptAmount] Amount
FROM 
	[Membership].[dbo].[ReceiptHeader]
WHERE
	[ReceiptAmount] <> 0
	and TimeCreated >= '1 Oct 2012'
	and MemberID <> 0
ORDER BY 
	ReceiptDate desc
