export const linkify = (text: string) => {
  const urlRegex = /(https?:\/\/[^\s]+)/g;
  return text.split(urlRegex).map((part, i) => {
    if (part.match(urlRegex)) {
      return {
        type: 'link' as const,
        url: part,
        key: i
      };
    }
    return {
      type: 'text' as const,
      content: part,
      key: i
    };
  });
};